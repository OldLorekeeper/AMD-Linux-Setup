## 2A.1 | App Sizes

Window rules for certain app sizes are set during setup by `Scripts/Operations/kwin_sync.zsh`.

> [!TIP]
> Common values can be changed in the terminal by running `edit-kwin` and `update-kwin`.
> You must change sizes by updating the Desktop and Laptop templates in `Resources/Kwin/`.

---

## 2A.2 | Other Rules

You may need to add these additional Window rules if you notice any issues with OpenGL displaying in the dock or PiP not working as intended.

### Hide OpenGL Renderer

| Setting | Value |
| :--- | :--- |
| **Window class** | Unimportant |
| **Match whole window class** | No |
| **Window types** | Normal windows |
| **Window title** | Exact Match: `OpenGL Renderer` |
| **Skip taskbar** | Yes (Apply initially) |

### PiP Above

| Setting | Value |
| :--- | :--- |
| **Window class** | Unimportant |
| **Match whole window class** | No |
| **Window types** | All selected |
| **Window title** | Exact Match: `Picture-in-picture` |
| **Keep above other windows** | Force: Yes |

---

### [Next ⇢](../03_Miscellaneous/3A_Tweaks.md)