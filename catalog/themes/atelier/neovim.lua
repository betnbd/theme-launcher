return {
    {
        "bjarneo/aether.nvim",
        branch = "v2",
        name = "aether",
        priority = 1000,
        opts = {
            transparent = false,
            colors = {
              bg = "#22221b",
              bg_dark = "#1c1c16",
              bg_highlight = "#302f27",
              fg = "#dcd9d6",
              fg_dark = "#929181",
              comment = "#6c6b5a",
              red = "#ba6236",       
              orange = "#ae7313",    
              yellow = "#a5980d",    
              green = "#7d9726",     
              cyan = "#5b9d48",      
              blue = "#36a166",      
              purple = "#5f9182",    
              magenta = "#9d6c7c",   
        }

        },
        config = function(_, opts)
            require("aether").setup(opts)
            vim.cmd.colorscheme("aether")

            -- Enable hot reload
            require("aether.hotreload").setup()
        end,
    },
    {
        "LazyVim/LazyVim",
        opts = {
            colorscheme = "aether",
        },
    },
}
