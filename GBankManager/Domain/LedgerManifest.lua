local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local ledgerManifest = {}

local BUCKET_SECONDS = 6 * 60 * 60

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function ensure_table(value)
    if type(value) == "table" then
        return value
    end

    return {}
end

local function encode_part(value)
    return trim(value):gsub("|", "/")
end

local function make_fingerprint(parts)
    local encoded = {}
    for index, part in ipairs(parts or {}) do
        encoded[index] = encode_part(part)
    end
    return table.concat(encoded, "|")
end

local function stable_hash(value)
    value = tostring(value or "")
    local hash = 5381
    for index = 1, #value do
        hash = ((hash * 33) + string.byte(value, index)) % 2147483647
    end
    return tostring(hash)
end

local function row_timestamp(row)
    row = type(row) == "table" and row or {}
    return tonumber(row.timestamp or row.when or 0) or 0
end

local function row_identity_token(kind, row)
    row = type(row) == "table" and row or {}
    local fingerprint = trim(row.fingerprint)
    if fingerprint ~= "" then
        return make_fingerprint({ kind, "fingerprint", fingerprint })
    end

    local entryId = trim(row.entryId)
    if entryId ~= "" then
        return make_fingerprint({ kind, "entry", entryId })
    end

    if kind == "money" then
        return make_fingerprint({
            kind,
            "fallback",
            row_timestamp(row),
            row.who or "Unknown",
            row.action or row.type or "Unknown",
            tonumber(row.amountCopper or row.amount or 0) or 0,
        })
    end

    return make_fingerprint({
        kind,
        "fallback",
        row_timestamp(row),
        row.who or "Unknown",
        row.action or row.type or "Unknown",
        tonumber(row.itemID or 0) or 0,
        tonumber(row.quantity or row.count or 0) or 0,
        row.tabName or row.sourceTabName or "-",
        row.fromTabName or "-",
    })
end

local function bucket_sort(left, right)
    local leftNumber = tonumber(left)
    local rightNumber = tonumber(right)
    if leftNumber and rightNumber and leftNumber ~= rightNumber then
        return leftNumber < rightNumber
    end
    return tostring(left) < tostring(right)
end

function ledgerManifest.BucketKey(timestamp)
    timestamp = tonumber(timestamp or 0) or 0
    return math.floor(timestamp / BUCKET_SECONDS)
end

local function add_row_to_buckets(buckets, kind, row)
    local key = ledgerManifest.BucketKey(row_timestamp(row))
    local bucket = buckets[key]
    if type(bucket) ~= "table" then
        bucket = {
            key = key,
            count = 0,
            tokens = {},
        }
        buckets[key] = bucket
    end

    bucket.count = (tonumber(bucket.count or 0) or 0) + 1
    bucket.tokens[#bucket.tokens + 1] = row_identity_token(kind, row)
end

local function finalize_buckets(buckets)
    local finalized = {}
    for key, bucket in pairs(buckets or {}) do
        local tokens = bucket.tokens or {}
        table.sort(tokens)
        finalized[key] = {
            key = key,
            count = tonumber(bucket.count or 0) or 0,
            hash = stable_hash(table.concat(tokens, "\n")),
        }
    end

    return finalized
end

local function sorted_bucket_keys(buckets)
    local keys = {}
    for key in pairs(buckets or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys, bucket_sort)
    return keys
end

function ledgerManifest.Build(ledger, options)
    ledger = ensure_table(ledger)
    options = ensure_table(options)

    local buckets = {}
    local itemCount = 0
    local moneyCount = 0

    for _, row in ipairs(ledger.itemLogs or {}) do
        itemCount = itemCount + 1
        add_row_to_buckets(buckets, "item", row)
    end

    for _, row in ipairs(ledger.moneyLogs or {}) do
        moneyCount = moneyCount + 1
        add_row_to_buckets(buckets, "money", row)
    end

    local finalized = finalize_buckets(buckets)
    local hashParts = {}
    for _, key in ipairs(sorted_bucket_keys(finalized)) do
        local bucket = finalized[key]
        hashParts[#hashParts + 1] = make_fingerprint({ key, bucket.count, bucket.hash })
    end

    local globalHash = stable_hash(table.concat(hashParts, "\n"))

    return {
        version = tostring(options.version or ((ns.constants or {}).ADDON_VERSION) or ""),
        ledgerProtocol = tonumber(options.ledgerProtocol or options.protocol or ((ns.constants or {}).LEDGER_PROTOCOL_VERSION) or 0) or 0,
        itemCount = itemCount,
        moneyCount = moneyCount,
        totalCount = itemCount + moneyCount,
        globalHash = globalHash,
        hash = globalHash,
        buckets = finalized,
    }
end

local function normalize_buckets(manifest)
    manifest = ensure_table(manifest)
    local normalized = {}
    for key, bucket in pairs(manifest.buckets or {}) do
        if type(bucket) == "table" then
            local normalizedKey = bucket.key ~= nil and bucket.key or key
            normalized[normalizedKey] = {
                key = normalizedKey,
                count = tonumber(bucket.count or 0) or 0,
                hash = tostring(bucket.hash or ""),
            }
        else
            normalized[key] = {
                key = key,
                count = nil,
                hash = tostring(bucket or ""),
            }
        end
    end
    return normalized
end

local function bucket_matches(localBucket, remoteBucket)
    if type(localBucket) ~= "table" or type(remoteBucket) ~= "table" then
        return false
    end

    if tostring(localBucket.hash or "") ~= tostring(remoteBucket.hash or "") then
        return false
    end

    if remoteBucket.count ~= nil and tonumber(localBucket.count or 0) ~= tonumber(remoteBucket.count or 0) then
        return false
    end

    return true
end

function ledgerManifest.Compare(localManifest, remoteManifest)
    localManifest = ensure_table(localManifest)
    remoteManifest = ensure_table(remoteManifest)

    local localBuckets = normalize_buckets(localManifest)
    local remoteBuckets = normalize_buckets(remoteManifest)
    local comparedBuckets = {}
    local differentBuckets = {}

    for _, key in ipairs(sorted_bucket_keys(localBuckets)) do
        comparedBuckets[key] = true
        if not bucket_matches(localBuckets[key], remoteBuckets[key]) then
            differentBuckets[#differentBuckets + 1] = key
        end
    end

    for _, key in ipairs(sorted_bucket_keys(remoteBuckets)) do
        if comparedBuckets[key] ~= true and not bucket_matches(localBuckets[key], remoteBuckets[key]) then
            differentBuckets[#differentBuckets + 1] = key
        end
    end

    table.sort(differentBuckets, bucket_sort)

    local protocolMismatch = tonumber(localManifest.ledgerProtocol or 0) ~= tonumber(remoteManifest.ledgerProtocol or 0)
    local localHash = tostring(localManifest.globalHash or localManifest.hash or "")
    local remoteHash = tostring(remoteManifest.globalHash or remoteManifest.hash or "")
    local hashMismatch = localHash ~= "" and remoteHash ~= "" and localHash ~= remoteHash

    return {
        matched = protocolMismatch ~= true and hashMismatch ~= true and #differentBuckets == 0,
        protocolMismatch = protocolMismatch,
        differentBuckets = differentBuckets,
    }
end

local function bucket_key_set(bucketKeys)
    local set = {}
    for _, key in ipairs(bucketKeys or {}) do
        set[tonumber(key) or tostring(key)] = true
    end
    return set
end

local function append_rows_for_buckets(target, rows, requested)
    for _, row in ipairs(rows or {}) do
        local key = ledgerManifest.BucketKey(row_timestamp(row))
        if requested[key] == true or requested[tostring(key)] == true then
            target[#target + 1] = row
        end
    end
end

function ledgerManifest.RowsForBuckets(ledger, bucketKeys)
    ledger = ensure_table(ledger)
    local requested = bucket_key_set(bucketKeys)
    local selected = {
        item = {},
        money = {},
    }

    append_rows_for_buckets(selected.item, ledger.itemLogs or {}, requested)
    append_rows_for_buckets(selected.money, ledger.moneyLogs or {}, requested)

    return selected
end

ns.modules.ledgerManifest = ledgerManifest
return ledgerManifest
