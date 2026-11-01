# Changelog

## [0.19.0](https://github.com/kohls-admin/kohls-admin/compare/v0.18.1...v0.19.0) (2026-11-01)


### Features

* **devcontainer:** migrate to custom Dockerfile and add Zed support ([47fa977](https://github.com/kohls-admin/kohls-admin/commit/47fa977c4fa8e60e968469cae71a0d5efc85f0aa))
* **general:** add poll command with multiple options ([fe44b6c](https://github.com/kohls-admin/kohls-admin/commit/fe44b6ce7301c6ca491ab564d0374c4dbb4ab593))


### Bug Fixes

* **chat:** support platform-integrated chat and TextChatCommands ([06aadc9](https://github.com/kohls-admin/kohls-admin/commit/06aadc963e7014790de102caaf92eb5aa1ebbe54))
* correctness bugs in parsing, limits, bans, data sync and remotes ([95ac9d3](https://github.com/kohls-admin/kohls-admin/commit/95ac9d394299698663ffcbc6d0d77bb0696e73dc))
* enforce per-pair chat checks and harden remote rate limits ([0273e67](https://github.com/kohls-admin/kohls-admin/commit/0273e6784d8792ae049bef12d12aca7e38010b87))
* **general:** harden poll validation, RichText, and results layout ([24217d2](https://github.com/kohls-admin/kohls-admin/commit/24217d209be20b0d09311372d5832aebe4308b3e))
* harden auth, data sync, command processing, VIP, and client UI ([eb269a3](https://github.com/kohls-admin/kohls-admin/commit/eb269a3bdced89f78920a3346c5adff36e5a36a0))
* harden Explorer paste/delete guards, VIP effect/title checks, Init schema, rawParse, and Table.fastRemove ([03318ac](https://github.com/kohls-admin/kohls-admin/commit/03318acda40dddb61c16bdc4ccae592c8d83de33))
* Harden group role validation and self-targeted chat delivery ([1bbf6d1](https://github.com/kohls-admin/kohls-admin/commit/1bbf6d1132d20c8bac5134b2f20661b02743e1fc))
* Incorrect target method call in starter tools ([bd67946](https://github.com/kohls-admin/kohls-admin/commit/bd67946a4af6bb695cbd40d06f4b522feb0a5b2f))
* **migrate:** Fix KAI log insertion, KChatSend lookup, and chat edge cases ([72a8758](https://github.com/kohls-admin/kohls-admin/commit/72a8758e5dd843d61e766eae74b8181197bb1ced))
* **migrate:** Update legacy KAI for TextChatService and text compliance ([dd0f73d](https://github.com/kohls-admin/kohls-admin/commit/dd0f73d1208d0db8c9218a7f77b4a50aa1560ba7))
* **ui:** disconnect Window Visible listener when reparented ([#578](https://github.com/kohls-admin/kohls-admin/issues/578)) ([b6ddb39](https://github.com/kohls-admin/kohls-admin/commit/b6ddb39fad435ff7a9faeadb82a43b1f05faf025))
* **vip:** stop hat texture and CRM changes leaking into the hat cache ([#579](https://github.com/kohls-admin/kohls-admin/issues/579))5 ([1f6936e](https://github.com/kohls-admin/kohls-admin/commit/1f6936eabd7f74f83011178e1ea2392cb68358cc))


### Security

* validate remote input and close server-side abuse paths ([3981c39](https://github.com/kohls-admin/kohls-admin/commit/3981c39646e073a000415e99f6029057eaee0938))


### Performance Improvements

* cheaper log trimming, cached title ownership, fewer broadcasts ([3bf4923](https://github.com/kohls-admin/kohls-admin/commit/3bf4923a9461e047b6b9e87873e42174814c4479))
