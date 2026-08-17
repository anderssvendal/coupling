import typescriptEslint from "typescript-eslint";

export default [
  {
    ignores: ["**/dist/**", "**/node_modules/**"],
  },
  {
    files: ["packages/coupling-vite/**/*.ts"],
    languageOptions: {
      parser: typescriptEslint.parser,
    },
    rules: {
      curly: ["error", "all"],
      semi: ["error", "always"],
    },
  },
];
