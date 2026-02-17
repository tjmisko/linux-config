return {
    "obsidian-nvim/obsidian.nvim",
    version = "*",
    lazy = false,
    dependencies = {
        "nvim-lua/plenary.nvim",
        "hrsh7th/nvim-cmp",
    },
    -- mappings option is deprecated; use Lazy keys instead
    opts = {
        workspaces = {
            { name = "Notes", path = "~/Documents/Notes" },
        },

        daily_notes = {
            folder = "daily",
            date_format = "%Y-%m-%d",
            template = "templates/daily.md",
        },

        new_notes_location = "zettelkasten",
        log_level = vim.log.levels.INFO,

        ---@param title string|?
        ---@return string
        note_id_function = function(title)
            local prefix = os.date("%Y-%m-%d") .. " - "
            if not title or title == "" then
                return prefix .. vim.fn.input("Title: ")
            end
            return prefix .. title
        end,

        completion = {
            nvim_cmp = true,
            min_chars = 2,
        },

        -- disable_frontmatter is deprecated; use frontmatter.enabled
        frontmatter = { enabled = false },

        -- legacy_commands is deprecated; turn it off and use `:Obsidian <subcommand>`
        legacy_commands = false,

        templates = {
            folder = "templates",
            date_format = "%Y-%m-%d",
            time_format = "%H:%M",
            substitutions = {},
        },

        picker = {
            name = "telescope.nvim",
        },

    },
    ui = {
        highlight_text = { hl_group = "ObsidianHighlightText" },
        tags = { hl_group = "ObsidianTag" },
        block_ids = { hl_group = "ObsidianBlockID" },
        hl_groups = {
            -- keep these as plain tables; catppuccin will style them via its overrides
            ObsidianTodo = { bold = true },
            ObsidianDone = { bold = true },
            ObsidianRightArrow = { bold = true },
            ObsidianTilde = { bold = true },
            ObsidianBullet = { bold = true },
            ObsidianRefText = {},
            ObsidianExtLinkIcon = {},
            ObsidianTag = { italic = true },
            ObsidianBlockID = { italic = true },
            ObsidianHighlightText = { bg = "#75662e" },
            ObsidianLink = { italic = true },
        },
    },

}
