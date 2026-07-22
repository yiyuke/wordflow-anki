# Contributing to Wordflow

Thanks for helping make vocabulary capture calmer and faster.

## Before opening a pull request

1. Create a focused branch.
2. Keep the workflow local-first and avoid adding analytics or unnecessary permissions.
3. Preserve both English and Simplified Chinese UI copy when changing visible text.
4. Run:

```bash
python3 -m unittest discover -s local_service/tests -v
node --check extension/service-worker.js
node --check extension/content.js
node --check extension/popup.js
native/build-app.sh
```

Please describe the user problem, the change, and how you verified it. For bugs, include macOS, browser, Anki, and AnkiConnect versions when relevant.

Use [GitHub Issues](https://github.com/yiyuke/wordflow-anki/issues) for bugs, feature ideas, and security reports that do not contain sensitive information.
