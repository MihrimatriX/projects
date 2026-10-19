from __future__ import annotations

from copy import deepcopy

from core.models import Rule
from core.settings import SettingsStore, rules_from_list, rules_to_list


def save_macro(rules: list[Rule]) -> None:
    store = SettingsStore.instance()
    store.settings.macro_rules = rules_to_list(rules)
    store.save()


def load_macro() -> list[Rule]:
    store = SettingsStore.instance()
    if not store.settings.macro_rules:
        return []
    return rules_from_list(store.settings.macro_rules)


def save_last_rules(rules: list[Rule]) -> None:
    store = SettingsStore.instance()
    store.settings.last_rules = rules_to_list(deepcopy(rules))
    store.save()


def load_last_rules() -> list[Rule]:
    store = SettingsStore.instance()
    if store.settings.last_rules:
        return rules_from_list(store.settings.last_rules)
    return []
