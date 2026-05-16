"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const vm = require("vm");
const Module = require("module");

const QUALITY_NAMES = {
    0: "Poor",
    1: "Common",
    2: "Uncommon",
    3: "Rare",
    4: "Epic",
    5: "Legendary",
    6: "Artifact",
    7: "Heirloom",
    8: "WoW Token",
};

const CATALOG_PROFILES = {
    FULL: "Full",
    PROCUREMENT_CURRENT_EXPANSION: "ProcurementCurrentExpansion",
};

const PROGRESS_BATCH_SIZE = 1000;

function parseArgs(argv) {
    const args = {};

    for (let index = 0; index < argv.length; index = index + 1) {
        const token = argv[index];
        if (!token.startsWith("--")) {
            continue;
        }

        const key = token.slice(2);
        const next = argv[index + 1];
        if (!next || next.startsWith("--")) {
            args[key] = true;
            continue;
        }

        args[key] = next;
        index = index + 1;
    }

    return args;
}

function ensureParentDirectory(filePath) {
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
}

function writeJsonFileAtomic(filePath, document) {
    ensureParentDirectory(filePath);
    const tempPath = `${filePath}.tmp`;
    fs.writeFileSync(tempPath, JSON.stringify(document, null, 2) + os.EOL, "utf8");
    fs.renameSync(tempPath, filePath);
}

function writeOutputDocumentAtomic(filePath, document) {
    writeJsonFileAtomic(filePath, document);
}

function safeUnlink(filePath) {
    try {
        fs.unlinkSync(filePath);
    } catch (error) {
        if (!error || error.code !== "ENOENT") {
            throw error;
        }
    }
}

function getLocaleKey(locale) {
    return String(locale || "en_US").replace("_", "");
}

function getQualityName(quality) {
    if (typeof quality !== "number" || Number.isNaN(quality)) {
        return null;
    }

    return QUALITY_NAMES[quality] || "Unknown";
}

function getCatalogProfile(profile) {
    const rawProfile = String(profile || CATALOG_PROFILES.PROCUREMENT_CURRENT_EXPANSION).trim().toLowerCase();
    if (rawProfile === "full") {
        return CATALOG_PROFILES.FULL;
    }

    if (rawProfile === "procurementcurrentexpansion") {
        return CATALOG_PROFILES.PROCUREMENT_CURRENT_EXPANSION;
    }

    throw new Error(`Unsupported catalog profile '${profile}'. Expected Full or ProcurementCurrentExpansion.`);
}

function getExecutionMode(mode) {
    const rawMode = String(mode || "Fresh").trim().toLowerCase();
    if (rawMode === "fresh") {
        return "Fresh";
    }

    if (rawMode === "resume") {
        return "Resume";
    }

    throw new Error(`Unsupported extraction mode '${mode}'. Expected Fresh or Resume.`);
}

function getItemID(row) {
    const rawValue = row.itemID ?? row.ItemID ?? row.ID ?? row.id;
    const itemID = Number(rawValue);
    if (!Number.isInteger(itemID) || itemID <= 0) {
        return null;
    }

    return itemID;
}

function getDisplayName(row) {
    const rawValue = row.Display_lang ?? row.display_lang ?? row.name ?? row.Name ?? "";
    const name = String(rawValue).trim();
    return name.length > 0 ? name : null;
}

function getQuality(row) {
    const rawValue = row.OverallQualityID ?? row.overallQualityID ?? row.quality ?? row.Quality;
    if (rawValue === null || rawValue === undefined || rawValue === "") {
        return null;
    }

    const quality = Number(rawValue);
    return Number.isInteger(quality) ? quality : null;
}

function getItemLevel(row) {
    const rawValue = row.ItemLevel ?? row.itemLevel;
    if (rawValue === null || rawValue === undefined || rawValue === "") {
        return null;
    }

    const itemLevel = Number(rawValue);
    if (!Number.isInteger(itemLevel) || itemLevel <= 0) {
        return null;
    }

    return itemLevel;
}

function getExpansionID(row) {
    const rawValue = row.ExpansionID ?? row.expansionID ?? row.expansionId;
    if (rawValue === null || rawValue === undefined || rawValue === "") {
        return null;
    }

    const expansionID = Number(rawValue);
    if (!Number.isInteger(expansionID) || expansionID < 0) {
        return null;
    }

    return expansionID;
}

function getClassID(row) {
    const rawValue = row.ClassID ?? row.classID ?? row.classId;
    if (rawValue === null || rawValue === undefined || rawValue === "") {
        return null;
    }

    const classID = Number(rawValue);
    if (!Number.isInteger(classID) || classID < 0) {
        return null;
    }

    return classID;
}

function getSubclassID(row) {
    const rawValue = row.SubclassID ?? row.subclassID ?? row.subclassId;
    if (rawValue === null || rawValue === undefined || rawValue === "") {
        return null;
    }

    const subclassID = Number(rawValue);
    if (!Number.isInteger(subclassID) || subclassID < 0) {
        return null;
    }

    return subclassID;
}

function getInventoryType(row) {
    const rawValue = row.InventoryType ?? row.inventoryType;
    if (rawValue === null || rawValue === undefined || rawValue === "") {
        return null;
    }

    const inventoryType = Number(rawValue);
    if (!Number.isInteger(inventoryType) || inventoryType < 0) {
        return null;
    }

    return inventoryType;
}

function getCraftedQuality(row) {
    const rawValue = row.CraftingQualityID
        ?? row.craftingQualityID
        ?? row.CraftedQualityID
        ?? row.craftedQualityID
        ?? row.craftedQuality
        ?? row.CraftedQuality
        ?? row.craftingQuality;

    if (rawValue === null || rawValue === undefined || rawValue === "") {
        return null;
    }

    const craftedQuality = Number(rawValue);
    if (!Number.isInteger(craftedQuality) || craftedQuality <= 0) {
        return null;
    }

    return craftedQuality;
}

function getCraftedQualityIcon(craftedQuality, row) {
    const rawValue = row.CraftingQualityIcon
        ?? row.craftingQualityIcon
        ?? row.CraftedQualityIcon
        ?? row.craftedQualityIcon;

    if (typeof rawValue === "string" && rawValue.trim().length > 0) {
        return rawValue.trim();
    }

    if (!Number.isInteger(craftedQuality) || craftedQuality <= 0) {
        return null;
    }

    return `Professions-ChatIcon-Quality-Tier${craftedQuality}`;
}

function shouldDeriveCraftedVariantGroup(items) {
    if (!Array.isArray(items) || items.length < 2 || items.length > 5) {
        return false;
    }

    const expansions = new Set();
    const qualities = new Set();
    const itemLevels = [];
    const itemIDs = [];

    for (const item of items) {
        const expansionID = Number(item.expansionID);
        const quality = Number(item.quality);
        const itemLevel = Number(item.itemLevel);
        const itemID = Number(item.itemID);

        if (!Number.isInteger(expansionID) || expansionID < 10) {
            return false;
        }

        if (!Number.isInteger(quality) || quality < 0) {
            return false;
        }

        if (!Number.isInteger(itemLevel) || itemLevel < 50) {
            return false;
        }

        if (!Number.isInteger(itemID) || itemID <= 0) {
            return false;
        }

        expansions.add(expansionID);
        qualities.add(quality);
        itemLevels.push(itemLevel);
        itemIDs.push(itemID);
    }

    const uniqueLevels = Array.from(new Set(itemLevels)).sort((left, right) => left - right);
    if (expansions.size !== 1 || qualities.size !== 1 || uniqueLevels.length !== items.length) {
        return false;
    }

    const minLevel = uniqueLevels[0];
    const maxLevel = uniqueLevels[uniqueLevels.length - 1];
    const minItemID = Math.min(...itemIDs);
    const maxItemID = Math.max(...itemIDs);

    return (maxLevel - minLevel) <= 40 && (maxItemID - minItemID) <= 32;
}

function applyDerivedCraftedVariantQualities(items) {
    const groupsByName = new Map();

    for (const item of items) {
        const name = String(item && item.name || "").trim();
        if (name.length === 0) {
            continue;
        }

        const group = groupsByName.get(name) || [];
        group.push(item);
        groupsByName.set(name, group);
    }

    for (const groupItems of groupsByName.values()) {
        if (!shouldDeriveCraftedVariantGroup(groupItems)) {
            continue;
        }

        const orderedItems = [...groupItems].sort((left, right) => {
            const leftLevel = Number(left.itemLevel) || 0;
            const rightLevel = Number(right.itemLevel) || 0;
            if (leftLevel !== rightLevel) {
                return leftLevel - rightLevel;
            }

            return (Number(left.itemID) || 0) - (Number(right.itemID) || 0);
        });

        for (let index = 0; index < orderedItems.length; index = index + 1) {
            const tier = index + 1;
            const item = orderedItems[index];
            if (item.craftedQuality === null || item.craftedQuality === undefined) {
                item.craftedQuality = tier;
            }
            if (!item.craftedQualityIcon) {
                item.craftedQualityIcon = `Professions-ChatIcon-Quality-Tier${tier}`;
            }
        }
    }
}

function getCurrentExpansionID(items) {
    let maxExpansionID = null;

    for (const item of items || []) {
        const expansionID = Number(item && item.expansionID);
        if (!Number.isInteger(expansionID) || expansionID < 0) {
            continue;
        }

        if (maxExpansionID === null || expansionID > maxExpansionID) {
            maxExpansionID = expansionID;
        }
    }

    return maxExpansionID;
}

function isProcurementCategoryItem(item) {
    const classID = Number(item && item.classID);
    const subclassID = Number(item && item.subclassID);

    if (!Number.isInteger(classID)) {
        return false;
    }

    if (classID === 1 || classID === 3 || classID === 8) {
        return true;
    }

    if (classID === 0 && subclassID === 6) {
        return true;
    }

    if (classID === 0) {
        return subclassID !== 6;
    }

    if (classID === 5 || classID === 7) {
        return true;
    }

    return classID === 15 && subclassID === 1;
}

function filterItemsByCatalogProfile(items, profile) {
    if (profile === CATALOG_PROFILES.FULL) {
        return [...(items || [])];
    }

    if (profile !== CATALOG_PROFILES.PROCUREMENT_CURRENT_EXPANSION) {
        throw new Error(`Unsupported catalog profile '${profile}'.`);
    }

    const currentExpansionID = getCurrentExpansionID(items);
    if (!Number.isInteger(currentExpansionID)) {
        return [];
    }

    return (items || []).filter((item) => Number(item.expansionID) === currentExpansionID && isProcurementCategoryItem(item));
}

function mergeRows(baseRows, hotfixRows) {
    const rowsByItemID = new Map();

    for (const sourceRow of baseRows || []) {
        const itemID = getItemID(sourceRow);
        if (itemID === null) {
            continue;
        }

        rowsByItemID.set(itemID, { ...sourceRow, itemID });
    }

    for (const sourceRow of hotfixRows || []) {
        const itemID = getItemID(sourceRow);
        if (itemID === null) {
            continue;
        }

        const previous = rowsByItemID.get(itemID) || { itemID };
        rowsByItemID.set(itemID, { ...previous, ...sourceRow, itemID });
    }

    return Array.from(rowsByItemID.values());
}

function normalizeRows(rows, options) {
    const normalized = [];

    for (const row of rows) {
        const itemID = getItemID(row);
        const name = getDisplayName(row);

        if (itemID === null || name === null) {
            continue;
        }

        const quality = getQuality(row);
        const craftedQuality = getCraftedQuality(row);
        normalized.push({
            itemID,
            name,
            quality,
            qualityName: getQualityName(quality),
            itemLevel: getItemLevel(row),
            expansionID: getExpansionID(row),
            classID: getClassID(row),
            subclassID: getSubclassID(row),
            inventoryType: getInventoryType(row),
            craftedQuality,
            craftedQualityIcon: getCraftedQualityIcon(craftedQuality, row),
            status: "confirmed",
            source: "local_client_item_db2",
            target: options.target,
            build: options.build || null,
            locale: options.locale,
            lastVerifiedAt: options.lastVerifiedAt,
        });
    }

    applyDerivedCraftedVariantQualities(normalized);
    return filterItemsByCatalogProfile(normalized, options.catalogProfile).sort((left, right) => left.itemID - right.itemID);
}

function normalizeRow(row, options) {
    const itemID = getItemID(row);
    const name = getDisplayName(row);

    if (itemID === null || name === null) {
        return null;
    }

    const quality = getQuality(row);
    const craftedQuality = getCraftedQuality(row);

    return {
        itemID,
        name,
        quality,
        qualityName: getQualityName(quality),
        itemLevel: getItemLevel(row),
        expansionID: getExpansionID(row),
        classID: getClassID(row),
        subclassID: getSubclassID(row),
        inventoryType: getInventoryType(row),
        craftedQuality,
        craftedQualityIcon: getCraftedQualityIcon(craftedQuality, row),
        status: "confirmed",
        source: "local_client_item_db2",
        target: options.target,
        build: options.build || null,
        locale: options.locale,
        lastVerifiedAt: options.lastVerifiedAt,
    };
}

function getOrderedRows(rows) {
    return [...(rows || [])].sort((left, right) => {
        const leftItemID = getItemID(left) || 0;
        const rightItemID = getItemID(right) || 0;
        return leftItemID - rightItemID;
    });
}

function getDefaultStatePath(outputPath, target, locale) {
    const outputDirectory = path.dirname(outputPath);
    const runtimeDirectory = path.dirname(outputDirectory);
    const stateDirectory = path.join(runtimeDirectory, "state");
    const safeTarget = String(target || "target").trim().toLowerCase().replace(/[^a-z0-9_-]+/g, "-");
    const safeLocale = String(locale || "en_US").trim().replace(/[^A-Za-z0-9_-]+/g, "_");
    return path.join(stateDirectory, `item-catalog-refresh-${safeTarget}-${safeLocale}.json`);
}

function getDefaultPartialRowsPath(progressPath) {
    return progressPath.replace(/\.json$/i, ".partial.jsonl");
}

function readState(statePath) {
    if (!fs.existsSync(statePath)) {
        return null;
    }

    return JSON.parse(fs.readFileSync(statePath, "utf8"));
}

function writeState(statePath, state) {
    writeJsonFileAtomic(statePath, state);
}

function readPartialItems(partialRowsPath) {
    if (!fs.existsSync(partialRowsPath)) {
        return [];
    }

    const content = fs.readFileSync(partialRowsPath, "utf8");
    const lines = content.split(/\r?\n/).filter((line) => line.trim().length > 0);
    return lines.map((line) => JSON.parse(line));
}

function appendPartialItems(partialRowsPath, items) {
    if (!items || items.length === 0) {
        return;
    }

    ensureParentDirectory(partialRowsPath);
    const lines = items.map((item) => JSON.stringify(item)).join(os.EOL) + os.EOL;
    fs.appendFileSync(partialRowsPath, lines, "utf8");
}

function writeProgressState(statePath, state, patch) {
    const nextState = {
        ...state,
        ...patch,
        updatedAt: new Date().toISOString(),
    };
    writeState(statePath, nextState);
    return nextState;
}

function createInitialState(options) {
    const now = new Date().toISOString();
    return {
        target: options.target,
        catalogProfile: options.catalogProfile,
        mode: options.mode,
        status: "running",
        phase: "extraction",
        build: options.build || null,
        locale: options.locale,
        wowRoot: options.wowRoot || null,
        clientDirectory: options.clientDirectory || null,
        outputPath: options.outputPath,
        partialRowsPath: options.partialRowsPath,
        startedAt: now,
        updatedAt: now,
        completedAt: null,
        resumeSupported: true,
        rawRowCountSeen: options.rawRowCountSeen || 0,
        normalizedCountWritten: options.normalizedCountWritten || 0,
        lastProcessedItemID: options.lastProcessedItemID || null,
        lastProcessedIndex: options.lastProcessedIndex || 0,
        highestSeenItemID: options.highestSeenItemID || null,
        failureClass: null,
        failureMessage: null,
    };
}

function validateResumeState(state, options) {
    if (!state) {
        throw new Error(`Resume requested but no saved progress state was found at ${options.statePath}. Re-run with -Fresh.`);
    }

    if (state.resumeSupported !== true) {
        throw new Error(`Resume requested but the saved state at ${options.statePath} is not resumable. Re-run with -Fresh.`);
    }

    if (String(state.phase || "") !== "extraction") {
        throw new Error(`Resume requested but the saved state at ${options.statePath} is not at an extraction boundary. Re-run with -Fresh.`);
    }

    if (String(state.target || "") !== String(options.target || "")) {
        throw new Error(`Resume requested for ${options.target}, but the saved state belongs to ${state.target}. Re-run with -Fresh.`);
    }

    if (String(state.catalogProfile || "") !== String(options.catalogProfile || "")) {
        throw new Error(`Resume requested for catalog profile ${options.catalogProfile}, but the saved state uses ${state.catalogProfile}. Re-run with -Fresh.`);
    }

    if (String(state.locale || "") !== String(options.locale || "")) {
        throw new Error(`Resume requested for locale ${options.locale}, but the saved state uses ${state.locale}. Re-run with -Fresh.`);
    }

    if (path.resolve(String(state.outputPath || "")) !== path.resolve(options.outputPath)) {
        throw new Error(`Resume requested with output path ${options.outputPath}, but the saved state expects ${state.outputPath}. Re-run with -Fresh.`);
    }

    if (path.resolve(String(state.partialRowsPath || "")) !== path.resolve(options.partialRowsPath)) {
        throw new Error(`Resume requested with partial rows path ${options.partialRowsPath}, but the saved state expects ${state.partialRowsPath}. Re-run with -Fresh.`);
    }

    if (String(state.status || "") === "completed") {
        throw new Error(`Resume requested but the saved state at ${options.statePath} is already completed. Re-run with -Fresh.`);
    }
}

function buildOutputDocument(items, options) {
    return {
        source: "local_client_item_db2",
        catalogProfile: options.catalogProfile,
        target: options.target,
        build: options.build || null,
        locale: options.locale,
        generatedAt: options.generatedAt,
        itemCount: items.length,
        items,
    };
}

function buildSummary(items, options) {
    return {
        status: "extracted",
        mode: options.mode,
        catalogProfile: options.catalogProfile,
        target: options.target,
        build: options.build || null,
        locale: options.locale,
        rawRowCount: options.rawRowCount,
        rawRowCountSeen: options.rawRowCount,
        normalizedCount: items.length,
        normalizedCountWritten: options.normalizedCountWritten,
        normalizedRowsPath: options.outputPath,
        progressPath: options.progressPath,
        partialRowsPath: options.partialRowsPath,
        resumeSupported: true,
        phase: "extraction",
        lastProcessedItemID: options.lastProcessedItemID,
        lastProcessedIndex: options.lastProcessedIndex,
        highestSeenItemID: options.highestSeenItemID,
        generatedAt: options.generatedAt,
        lastVerifiedAt: options.lastVerifiedAt,
        source: "local_client_item_db2",
    };
}

function loadFixtureRows(fixturePath) {
    const fixture = JSON.parse(fs.readFileSync(fixturePath, "utf8"));
    const mergedRows = mergeRows(fixture.baseRows || fixture.rows || [], fixture.hotfixRows || []);

    return {
        build: fixture.build || null,
        rows: mergedRows,
        rawRowCount: mergedRows.length,
    };
}

function createWowExportSandbox(appPath, runtimeDataPath) {
    const wowRequire = Module.createRequire(appPath);
    const executablePath = path.join(path.dirname(appPath), "..", "wow.export.exe");
    const realProcess = process;
    const fakeProcess = Object.create(realProcess);
    fakeProcess.execPath = path.resolve(executablePath);
    const fakeWindow = {
        addEventListener() {
        },
        removeEventListener() {
        },
        innerWidth: 0,
        innerHeight: 0,
        location: {
            reload() {
            },
        },
        navigator: {
            userAgent: "node",
        },
        performance: globalThis.performance,
        trustedTypes: null,
    };
    const fakeDocument = {
        readyState: "complete",
        body: {
            offsetHeight: 0,
        },
        head: {
            appendChild() {
            },
        },
        activeElement: null,
        addEventListener() {
        },
        removeEventListener() {
        },
        querySelector() {
            return null;
        },
        createTreeWalker() {
            return {
                nextNode() {
                    return null;
                },
            };
        },
        createElement() {
            return {
                style: {},
                classList: {
                    add() {
                    },
                    remove() {
                    },
                    contains() {
                        return false;
                    },
                },
                appendChild() {
                },
                removeChild() {
                },
                setAttribute() {
                },
                removeAttribute() {
                },
                getContext() {
                    return {};
                },
                focus() {
                },
            };
        },
    };

    const sandbox = {
        console,
        Buffer,
        require: wowRequire,
        module: { exports: {} },
        exports: {},
        process: fakeProcess,
        __filename: appPath,
        __dirname: path.dirname(appPath),
        setTimeout,
        clearTimeout,
        setInterval,
        clearInterval,
        setImmediate,
        clearImmediate,
        queueMicrotask,
        requestAnimationFrame(callback) {
            return setTimeout(() => callback(Date.now()), 0);
        },
        cancelAnimationFrame(handle) {
            clearTimeout(handle);
        },
        TextEncoder,
        TextDecoder,
        URL,
        URLSearchParams,
        performance,
        fetch,
        Headers,
        Request,
        Response,
        AbortController,
        AbortSignal,
        BUILD_RELEASE: true,
        chrome: {
            runtime: {
                reload() {
                },
            },
        },
        nw: {
            __dirname: path.dirname(appPath),
            App: {
                argv: [],
                dataPath: runtimeDataPath,
                manifest: {
                    version: "0.2.17",
                    flavour: "portable",
                    guid: "gbm-local-extract",
                },
            },
            Shell: {
                openItem() {
                },
                openExternal() {
                },
            },
            Window: {
                get() {
                    return {
                        setProgressBar() {
                        },
                        on() {
                        },
                        showDevTools() {
                        },
                        resizeTo() {
                        },
                        moveTo() {
                        },
                        focus() {
                        },
                        close() {
                        },
                    };
                },
            },
            Clipboard: {
                get() {
                    return {
                        set() {
                        },
                    };
                },
            },
        },
        document: fakeDocument,
    };

    sandbox.window = fakeWindow;
    sandbox.self = sandbox;
    sandbox.global = sandbox;
    sandbox.globalThis = sandbox;
    sandbox.navigator = fakeWindow.navigator;
    sandbox.location = fakeWindow.location;

    return sandbox;
}

function loadWowExportModules(wowExportRoot, runtimeDataPath) {
    const appPath = path.join(wowExportRoot, "src", "app.js");
    const source = fs.readFileSync(appPath, "utf8");
    const marker = '(async () => {\n  if (document.readyState === "loading")';
    const markerIndex = source.indexOf(marker);
    if (markerIndex < 0) {
        throw new Error("Unable to locate the wow.export bootstrap marker in src/app.js.");
    }

    ensureParentDirectory(path.join(runtimeDataPath, "runtime.log"));
    const sandbox = createWowExportSandbox(appPath, runtimeDataPath);
    const context = vm.createContext(sandbox);
    vm.runInContext(source.slice(0, markerIndex), context, { filename: appPath });

    return {
        context,
        requireCore: context.require_core,
        requireCascLocal: context.require_casc_source_local,
        requireDb2: context.require_db2,
        requireBuildCache: context.require_build_cache,
        requireLocaleFlags: context.require_locale_flags,
    };
}

async function loadLiveRows(options) {
    const modules = loadWowExportModules(options.wowExportRoot, options.runtimeDataPath);
    const core = modules.requireCore();
    core.view = core.makeNewView();
    core.view.$watch = function watch(pathExpression, callback, watchOptions) {
        if (watchOptions && watchOptions.immediate) {
            callback(pathExpression === "config.cascLocale" ? core.view.config.cascLocale : undefined);
        }

        return function unwatch() {
        };
    };

    core.view.config = {
        cascLocale: modules.requireLocaleFlags().flags[getLocaleKey(options.locale)] || modules.requireLocaleFlags().flags.enUS,
        enableBinaryListfile: true,
        listfileCacheRefresh: 365,
    };
    core.view.selectedCDNRegion = { tag: "us", name: "Americas" };

    const CASCLocal = modules.requireCascLocal();
    const BuildCache = modules.requireBuildCache();
    const db2 = modules.requireDb2();
    const casc = new CASCLocal(options.wowRoot);

    await casc.init();
    const buildIndex = casc.builds.findIndex((entry) => entry.Product === options.product);
    if (buildIndex < 0) {
        throw new Error(`Unable to find product '${options.product}' in the selected client build list.`);
    }

    casc.build = casc.builds[buildIndex];
    casc.cache = new BuildCache(casc.build.BuildKey);
    await casc.cache.init();

    core.showLoadingScreen(6, "Loading local client item data");
    try {
        await casc.loadConfigs();
        await casc.loadIndexes();
        await casc.loadEncoding();
        await casc.loadRoot();
        core.view.casc = casc;
        await casc.prepareListfile();
        await casc.loadListfile(casc.build.BuildKey);
    } finally {
        core.hideLoadingScreen();
    }

    // wow.export resolves the selected product from the shared install root and
    // exposes the effective ItemSparse row view through db2.getAllRows(). We
    // merge in Item rows as well so the maintainer pipeline can classify the
    // shipped procurement catalog by class/subclass without a second source.
    const sparseRows = await db2.ItemSparse.getAllRows();
    const rows = new Map();

    try {
        const itemRows = await db2.Item.getAllRows();
        for (const [itemID, itemRow] of itemRows.entries()) {
            rows.set(itemID, { itemID, ...itemRow });
        }
    } catch (error) {
        // Some local wow.export runtimes ship ItemSparse DBDs but not Item DBDs.
        // Classification can still proceed when those fields are present on
        // ItemSparse rows, so treat Item.db2 metadata as opportunistic.
    }

    for (const [itemID, sparseRow] of sparseRows.entries()) {
        const previous = rows.get(itemID) || { itemID };
        rows.set(itemID, { ...previous, ...sparseRow, itemID });
    }

    return {
        build: casc.getBuildName ? casc.getBuildName() : (casc.build && casc.build.Version) || null,
        rows: Array.from(rows, ([itemID, row]) => ({ itemID, ...row })),
        rawRowCount: rows.size,
    };
}

async function main() {
    const args = parseArgs(process.argv.slice(2));
    const now = new Date();
    const generatedAt = now.toISOString().slice(0, 10);
    const lastVerifiedAt = now.toISOString();
    const outputPath = path.resolve(args.output || path.join("tools", "catalog", "runtime", "item-catalog-extracted.json"));
    const target = String(args.target || "Retail");
    const locale = String(args.locale || "en_US");
    const mode = getExecutionMode(args.mode);
    const catalogProfile = getCatalogProfile(args["catalog-profile"]);
    const progressPath = path.resolve(args["progress-path"] || getDefaultStatePath(outputPath, target, locale));
    const partialRowsPath = path.resolve(args["partial-rows-path"] || getDefaultPartialRowsPath(progressPath));

    let extracted;
    if (args.fixture) {
        extracted = loadFixtureRows(path.resolve(args.fixture));
    } else {
        if (!args["wow-root"]) {
            throw new Error("A WoW install root is required for live extraction.");
        }

        if (!args.product) {
            throw new Error("A product code is required for live extraction.");
        }

        if (!args["wow-export-root"]) {
            throw new Error("A wow.export runtime root is required for live extraction.");
        }

        extracted = await loadLiveRows({
            wowRoot: path.resolve(args["wow-root"]),
            locale,
            product: String(args.product),
            runtimeDataPath: path.resolve(args["runtime-data-path"] || path.join("tools", "catalog", "runtime", "wow-export-data")),
            wowExportRoot: path.resolve(args["wow-export-root"]),
        });
    }

    const orderedRows = getOrderedRows(extracted.rows);
    const highestSeenItemID = orderedRows.length > 0 ? getItemID(orderedRows[orderedRows.length - 1]) : null;
    const baseOptions = {
        target,
        catalogProfile,
        mode,
        build: extracted.build,
        locale,
        wowRoot: args["wow-root"] ? path.resolve(args["wow-root"]) : null,
        clientDirectory: null,
        outputPath,
        partialRowsPath,
        statePath: progressPath,
    };

    let existingItems = [];
    let lastProcessedItemID = null;
    let lastProcessedIndex = 0;

    if (mode === "Fresh") {
        safeUnlink(progressPath);
        safeUnlink(partialRowsPath);
        safeUnlink(outputPath);
    } else {
        const resumeState = readState(progressPath);
        validateResumeState(resumeState, baseOptions);
        existingItems = readPartialItems(partialRowsPath);
        if (existingItems.length > 0) {
            lastProcessedItemID = Number(existingItems[existingItems.length - 1].itemID) || resumeState.lastProcessedItemID || null;
            lastProcessedIndex = existingItems.length;
        } else {
            lastProcessedItemID = resumeState.lastProcessedItemID || null;
            lastProcessedIndex = Number(resumeState.lastProcessedIndex || 0);
        }
    }

    let progressState = createInitialState({
        ...baseOptions,
        rawRowCountSeen: extracted.rawRowCount,
        normalizedCountWritten: existingItems.length,
        lastProcessedItemID,
        lastProcessedIndex,
        highestSeenItemID,
    });
    writeState(progressPath, progressState);

    const normalized = existingItems.slice();
    let pendingBatch = [];
    let processedIndex = lastProcessedIndex;
    let currentLastProcessedItemID = lastProcessedItemID;

    try {
        for (const row of orderedRows) {
            const rowItemID = getItemID(row);
            if (rowItemID === null) {
                continue;
            }

            if (currentLastProcessedItemID !== null && rowItemID <= currentLastProcessedItemID) {
                continue;
            }

            const normalizedRow = normalizeRow(row, {
                target,
                catalogProfile,
                build: extracted.build,
                locale,
                lastVerifiedAt,
            });

            processedIndex = processedIndex + 1;
            currentLastProcessedItemID = rowItemID;

            if (normalizedRow) {
                pendingBatch.push(normalizedRow);
                normalized.push(normalizedRow);
            }

            if (pendingBatch.length >= PROGRESS_BATCH_SIZE) {
                appendPartialItems(partialRowsPath, pendingBatch);
                pendingBatch = [];
                progressState = writeProgressState(progressPath, progressState, {
                    status: "running",
                    phase: "extraction",
                    build: extracted.build || null,
                    rawRowCountSeen: extracted.rawRowCount,
                    normalizedCountWritten: normalized.length,
                    lastProcessedItemID: currentLastProcessedItemID,
                    lastProcessedIndex: processedIndex,
                    highestSeenItemID,
                    failureClass: null,
                    failureMessage: null,
                });
            }
        }

        if (pendingBatch.length > 0) {
            appendPartialItems(partialRowsPath, pendingBatch);
            pendingBatch = [];
        }

        applyDerivedCraftedVariantQualities(normalized);
        const filteredItems = filterItemsByCatalogProfile(normalized, catalogProfile);
        writeOutputDocumentAtomic(outputPath, buildOutputDocument(filteredItems, {
            target,
            catalogProfile,
            build: extracted.build,
            locale,
            generatedAt,
        }));

        progressState = writeProgressState(progressPath, progressState, {
            status: "completed",
            phase: "extraction",
            build: extracted.build || null,
            normalizedCountWritten: filteredItems.length,
            lastProcessedItemID: currentLastProcessedItemID,
            lastProcessedIndex: processedIndex,
            highestSeenItemID,
            failureClass: null,
            failureMessage: null,
            completedAt: new Date().toISOString(),
        });
    } catch (error) {
        writeProgressState(progressPath, progressState, {
            status: "failed",
            phase: "extraction",
            build: extracted.build || null,
            normalizedCountWritten: normalized.length,
            lastProcessedItemID: currentLastProcessedItemID,
            lastProcessedIndex: processedIndex,
            highestSeenItemID,
            failureClass: "extraction",
            failureMessage: error && error.message ? error.message : String(error),
        });
        throw error;
    }

    const filteredItems = filterItemsByCatalogProfile(normalized, catalogProfile);
    const summary = buildSummary(filteredItems, {
        mode,
        catalogProfile,
        target,
        build: extracted.build,
        locale,
        rawRowCount: extracted.rawRowCount,
        normalizedCountWritten: filteredItems.length,
        outputPath,
        progressPath,
        partialRowsPath,
        generatedAt,
        lastVerifiedAt,
        lastProcessedItemID: currentLastProcessedItemID,
        lastProcessedIndex: processedIndex,
        highestSeenItemID,
    });

    process.stdout.write(JSON.stringify(summary));
}

main().catch((error) => {
    const message = error && (error.stack || error.message) ? (error.stack || error.message) : String(error);
    process.stderr.write(message + os.EOL);
    process.exit(1);
});
