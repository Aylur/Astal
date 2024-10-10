import eslint from "@eslint/js"
import tseslint from "typescript-eslint"
import stylistic from "@stylistic/eslint-plugin"
import pluginVue from "eslint-plugin-vue"

export default tseslint.config({
    ignores: [".vitepress/cache/*"],
    extends: [
        eslint.configs.recommended,
        ...tseslint.configs.recommended,
        ...pluginVue.configs["flat/recommended"],
        stylistic.configs.customize({
            semi: false,
            indent: 4,
            quotes: "double",
        }),
    ],
    rules: {
        "vue/multi-word-component-names": ["off"],
        "vue/html-indent": ["error", 4],
        "vue/max-attributes-per-line": ["error", {
            singleline: {
                max: 2,
            },
            multiline: {
                max: 1,
            },
        }],
    },
})
