-- FIT2099 mandates IntelliJ. For a project with no build file that just means
-- "src/ is the source root, compile it somewhere, run the main class" -- so this
-- mirrors that model rather than introducing Gradle, and keeps nvim and IntelliJ
-- interchangeable on the same checkout.
--
-- Nothing here writes into the repo: jdtls keeps its Eclipse metadata under
-- ~/.cache/nvim/jdtls/<project>/, so there is no .project/.classpath for tutors
-- or markers to trip over. The only artefact is bin/, which is gitignored.

local home = os.getenv("HOME")

-- Sources the project is not allowed to change: FIT2099 ships its engine under
-- src/edu/ and forbids editing it, so a warning there can never be actioned and
-- only buries the ones that can. Matched as a plain substring of the file path;
-- add an entry for any other project that vendors code the same way.
local read_only_sources = { "/src/edu/" }

-- The javac side of the same rule, by package rather than path, since doclint is
-- the only warning source the build turns on and -Xdoclint/package: is how it is
-- scoped. Written without the leading `-`; doclint_exclusion adds it.
local read_only_packages = { "edu.monash.*" }

--- Whether `path` lives in a tree the project is not allowed to change.
--- @param path string|nil
--- @return boolean
local function read_only(path)
  for _, fragment in ipairs(read_only_sources) do
    if path and path:find(fragment, 1, true) then
      return true
    end
  end
  return false
end

--- read_only for an LSP document URI. jdt.ls also reports on `jdt://` URIs for
--- decompiled class files, which uri_to_fname cannot parse -- those are library
--- code, not project code, so a failure to convert is simply not a match.
--- @param uri string|nil
--- @return boolean
local function read_only_uri(uri)
  local ok, path = pcall(vim.uri_to_fname, uri or "")
  return ok and read_only(path)
end

--- The single -Xdoclint/package: argument covering read_only_packages.
--- @return string
local function doclint_exclusion()
  local excluded = vim.tbl_map(function(package)
    return "-" .. package
  end, read_only_packages)
  return "-Xdoclint/package:" .. table.concat(excluded, ",")
end

-- Errors survive the filter. Read-only code is known to compile, so an error in
-- it is a statement about the *setup* -- an unresolved source path or runtime --
-- and that is worth seeing. Drop the severity test to silence those too.
local function errors_only(diagnostics)
  return vim.tbl_filter(function(diagnostic)
    -- severity is optional in LSP; an unranked diagnostic is kept.
    return diagnostic.severity == nil or diagnostic.severity == vim.diagnostic.severity.ERROR
  end, diagnostics or {})
end

-- Filtering in the handler rather than hiding warnings at display time keeps them
-- out of vim.diagnostic altogether: no virtual text or signs, and nothing left to
-- count in the statusline, `]d`, or <leader>xx. jdt.ls pushes diagnostics; the
-- pull request is wrapped too, so the filter survives a jdt.ls that starts
-- advertising diagnosticProvider.
local function read_only_filter()
  return {
    ["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
      if result and read_only_uri(result.uri) then
        result.diagnostics = errors_only(result.diagnostics)
      end
      return vim.lsp.handlers["textDocument/publishDiagnostics"](err, result, ctx, config)
    end,
    ["textDocument/diagnostic"] = function(err, result, ctx, config)
      if result and result.items and read_only_uri(vim.tbl_get(ctx, "params", "textDocument", "uri")) then
        result.items = errors_only(result.items)
      end
      return vim.lsp.handlers["textDocument/diagnostic"](err, result, ctx, config)
    end,
  }
end

-- The unit pins Java 17 Corretto in .sdkmanrc. sdkman's auto-env only fires in an
-- interactive shell that cd'd into the project, so if nvim was launched from
-- anywhere else `javac` would silently be whatever `current` points at (25.0.3).
-- Resolve the JDK from .sdkmanrc instead, so a build always uses the unit's
-- version regardless of how nvim was started.
local function project_jdk(root)
  local rc = vim.fs.joinpath(root, ".sdkmanrc")
  if not vim.uv.fs_stat(rc) then
    return nil
  end
  for _, line in ipairs(vim.fn.readfile(rc)) do
    local version = line:match("^%s*java%s*=%s*(%S+)")
    if version then
      local dir = vim.fs.joinpath(home, ".sdkman/candidates/java", version)
      if vim.uv.fs_stat(dir) then
        return dir
      end
      vim.notify(
        (".sdkmanrc requests java %s but it is not installed (sdk install java %s)"):format(version, version),
        vim.log.levels.WARN
      )
      return nil
    end
  end
end

local function project_root()
  local buf = vim.api.nvim_buf_get_name(0)
  return vim.fs.root(buf ~= "" and buf or vim.uv.cwd(), { ".git", "src" }) or vim.uv.cwd()
end

local function sources(root)
  return vim.fn.glob(vim.fs.joinpath(root, "src", "**", "*.java"), true, true)
end

--- The fully-qualified name of the class in `file`, if it declares a main.
--- @param file string
--- @return string|nil
local function main_in(file)
  local ok, lines = pcall(vim.fn.readfile, file)
  if not ok then
    return nil
  end
  local text = table.concat(lines, "\n")
  if not text:find("static%s+void%s+main%s*%(") then
    return nil
  end
  local package = text:match("^%s*package%s+([%w%.]+)%s*;") or text:match("\n%s*package%s+([%w%.]+)%s*;")
  local name = vim.fn.fnamemodify(file, ":t:r")
  return package and (package .. "." .. name) or name
end

--- Every class under src/ declaring a main, project code before engine demos.
--- @param root string
--- @return { fqn: string, read_only: boolean }[]
local function main_classes(root)
  local found = {}
  for _, file in ipairs(sources(root)) do
    local fqn = main_in(file)
    if fqn then
      table.insert(found, { fqn = fqn, read_only = read_only(file) })
    end
  end
  -- Project mains first, so the common choice is the one already under the
  -- cursor when the picker opens.
  table.sort(found, function(a, b)
    if a.read_only ~= b.read_only then
      return b.read_only
    end
    return a.fqn < b.fqn
  end)
  return found
end

-- Which class <leader>jr runs. Scanning for "the" main class cannot work here:
-- the engine ships demo Applications under src/edu/ and a glob finds
-- conwayslife's long before the project's own, so the run key silently launched
-- a demo the project is not even allowed to edit.
--
-- IntelliJ resolves this from a run configuration -- the class you asked for,
-- remembered until you ask for another. This is the same idea scoped to the
-- session: the buffer you are in wins, otherwise whatever ran last, and the
-- picker appears only when there is genuinely nothing better than a guess.
local last_main = {}

--- Resolve the class to run for `root` and pass it to `callback`, which may be
--- invoked asynchronously. Not called at all if the choice is abandoned.
--- @param root string
--- @param callback fun(main: string)
local function resolve_main(root, callback)
  local function chosen(fqn)
    last_main[root] = fqn
    callback(fqn)
  end

  local current = main_in(vim.api.nvim_buf_get_name(0))
  if current then
    return chosen(current)
  end

  if last_main[root] then
    return callback(last_main[root])
  end

  local found = main_classes(root)
  if #found == 0 then
    return vim.notify("No class with a main method found under src/", vim.log.levels.WARN)
  end
  if #found == 1 then
    return chosen(found[1].fqn)
  end

  vim.ui.select(found, {
    prompt = "Run which main class?",
    format_item = function(item)
      return item.read_only and (item.fqn .. "  (engine demo)") or item.fqn
    end,
  }, function(choice)
    if choice then
      chosen(choice.fqn)
    end
  end)
end

-- Build (and optionally run) in a terminal, so javac diagnostics are readable
-- rather than swallowed. interactive=false keeps the window open on exit.
local function javac_run(run)
  return function()
    -- Save first: every step below reads from disk, so an unsaved buffer would
    -- otherwise be compiled -- and searched for a main -- in its previous state,
    -- and a never-saved file would not be found at all.
    vim.cmd("silent! wall")

    local root = project_root()
    local files = sources(root)
    if #files == 0 then
      return vim.notify("No .java files under " .. vim.fs.joinpath(root, "src"), vim.log.levels.WARN)
    end

    local jdk = project_jdk(root)
    local javac = jdk and vim.fs.joinpath(jdk, "bin", "javac") or "javac"
    local java = jdk and vim.fs.joinpath(jdk, "bin", "java") or "java"

    -- Mirror the jdtls javadoc checks in jdt-javadoc.prefs, so <leader>jb reports
    -- the same gaps the editor does. doclint's `missing` group covers absent
    -- comments and tags; `/protected` limits it to protected-and-above. These are
    -- warnings, so an undocumented API still compiles. read_only_packages is
    -- excluded here for the same reason it is filtered out of the editor's
    -- diagnostics: nothing in it can be fixed.
    local parts = {
      vim.fn.shellescape(javac),
      "-d",
      "bin",
      "-encoding",
      "UTF-8",
      "-Xdoclint:missing/protected",
      vim.fn.shellescape(doclint_exclusion()),
    }
    for _, file in ipairs(files) do
      table.insert(parts, vim.fn.shellescape(file))
    end
    local compile = table.concat(parts, " ")

    local function launch(cmd)
      Snacks.terminal.open(cmd, { cwd = root, interactive = false, win = { position = "bottom" } })
    end

    if not run then
      return launch(compile)
    end

    -- resolve_main may prompt, so the terminal is opened from its callback
    -- rather than after it returns.
    resolve_main(root, function(main)
      launch(compile .. " && " .. vim.fn.shellescape(java) .. " -cp bin " .. vim.fn.shellescape(main))
    end)
  end
end

-- nvim applies .editorconfig itself and records what it applied in
-- b:editorconfig, so read the property rather than 'shiftwidth' -- shiftwidth is
-- 2 by LazyVim default and cannot tell "the project asked for 2" from "nobody
-- asked". Only properties nvim understands land there, so a file with no
-- indent_size simply reads as absent and keeps Google style.
local warned = {}

local function warn_once(key, message)
  if not warned[key] then
    warned[key] = true
    vim.notify(message, vim.log.levels.WARN)
  end
end

--- Extra google-java-format args implied by the buffer's .editorconfig.
--- @param bufnr integer
--- @return string[]
local function gjf_style(bufnr)
  local editorconfig = vim.b[bufnr].editorconfig
  if type(editorconfig) ~= "table" then
    return {}
  end

  if editorconfig.indent_style == "tab" then
    warn_once("tab", ".editorconfig asks for tabs; google-java-format only emits spaces")
    return {}
  end

  local size = tonumber(editorconfig.indent_size) or tonumber(editorconfig.tab_width)
  if size == 4 then
    return { "--aosp" }
  end
  if size and size ~= 2 then
    warn_once("size:" .. size, ("google-java-format has no indent_size %d; using Google style (2)"):format(size))
  end
  return {}
end

return {
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      -- jdtls itself must run on Java 21+, which is independent of the Java the
      -- *project* targets. The mason `jdtls` binary is a Python launcher, so pass
      -- the JVM via its --java-executable flag; prepending `java` to cmd makes it
      -- try to load the launcher script as a main class.
      if opts.cmd then
        table.insert(opts.cmd, "--java-executable=" .. home .. "/.sdkman/candidates/java/25.0.3-tem/bin/java")
      end

      -- LazyVim passes opts.jdtls the config it is about to hand to
      -- start_or_attach, which is the one place a handler can be installed on the
      -- jdtls client alone rather than on every server. nvim-jdtls only fills in
      -- handlers it does not find here, so this table is left intact.
      opts.jdtls = function(config)
        config.handlers = vim.tbl_extend("force", config.handlers or {}, read_only_filter())
      end

      opts.settings = vim.tbl_deep_extend("force", opts.settings or {}, {
        java = {
          configuration = {
            runtimes = {
              {
                name = "JavaSE-17",
                path = home .. "/.sdkman/candidates/java/17.0.20-amzn",
                default = true,
              },
              {
                name = "JavaSE-25",
                path = home .. "/.sdkman/candidates/java/25.0.3-tem",
              },
            },
          },
          -- With no pom.xml/build.gradle, jdtls falls back to "invisible project"
          -- mode and otherwise has no idea src/ is a source root -- which is why
          -- it reports phantom errors on a perfectly valid file. This is the
          -- equivalent of IntelliJ's "Mark Directory as > Sources Root".
          project = {
            sourcePaths = { "src" },
            outputPath = "bin",
            referencedLibraries = { "lib/**/*.jar" },
          },
          -- The "checks" half of the setup: jdtls is the compiler, so these are
          -- real diagnostics rather than style opinions.
          compile = {
            nullAnalysis = { mode = "automatic" },
          },
          -- Formatting belongs to conform (google-java-format, below). Left on,
          -- jdtls is a second formatter that LazyVim falls back to whenever
          -- conform has nothing available, and it reformats to Eclipse defaults
          -- at a width taken from 'shiftwidth' -- which looks exactly like a
          -- successful google-java-format run and is not one. Disabled, jdtls
          -- still answers a formatting request but returns no edits, so the
          -- fallback becomes a no-op instead of the wrong style.
          format = { enabled = false },
          -- Missing javadoc on the public/protected API is a compiler problem in
          -- JDT, but there is no LSP setting to turn it on -- the javadoc options
          -- exist only as Eclipse compiler preferences. Point jdtls at a .prefs
          -- file instead. Equivalent to IntelliJ's "missing javadoc" inspection.
          settings = {
            url = home .. "/.config/nvim/java/jdt-javadoc.prefs",
          },
          completion = {
            importOrder = { "java", "javax", "com", "org" },
          },
          sources = {
            organizeImports = { starThreshold = 9999, staticStarThreshold = 9999 },
          },
        },
      })
    end,
    keys = {
      { "<leader>j", "", desc = "+java", ft = "java" },
      { "<leader>jb", javac_run(false), desc = "Build (javac -> bin/)", ft = "java" },
      { "<leader>jr", javac_run(true), desc = "Build & Run main class", ft = "java" },
    },
  },

  -- The formatter is a hard dependency now that jdtls no longer formats: without
  -- it a java buffer has no working formatter at all, which is the intended
  -- failure -- a save that visibly does nothing, rather than one that quietly
  -- writes the wrong style. `:LazyFormatInfo` names the formatter in use.
  { "mason-org/mason.nvim", opts = { ensure_installed = { "google-java-format" } } },

  -- google-java-format in true Google style: 2-space indent, 100 columns,
  -- Google's import order. Formats on save via LazyVim's autoformat.
  --
  -- google-java-format has exactly two indent widths -- Google style (2) and
  -- --aosp (4) -- and no flag for anything else. A project .editorconfig is the
  -- stronger signal where one exists, since it is checked into the repo and
  -- IntelliJ obeys it too, so indent_size decides which of the two is used.
  -- Anything gjf cannot express warns once per session instead of silently
  -- formatting against the project's own stated config.
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        -- lsp_format = "never" is the same guard as `format.enabled = false` on
        -- the jdtls side, for the path where conform is called directly.
        java = { "google-java-format", lsp_format = "never" },
      },
      formatters = {
        ["google-java-format"] = function(bufnr)
          return { prepend_args = gjf_style(bufnr) }
        end,
      },
    },
  },
}
