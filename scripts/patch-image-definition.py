#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import sys
import yaml
import logging
from typing import Any, Dict

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")


class YamlFileError(Exception):
    pass


def load_yaml_file(path: str) -> Dict[str, Any]:
    try:
        with open(path, "r") as f:
            data = yaml.safe_load(f)
        if not isinstance(data, dict):
            raise YamlFileError(
                "YAML file does not contain a valid dictionary at the top level."
            )
        return data
    except yaml.YAMLError as exc:
        raise YamlFileError(f"YAML parsing error: {exc}")
    except Exception as exc:
        raise YamlFileError(f"Error: {exc}")


def save_yaml_file(path: str, data: Dict[str, Any]) -> None:
    try:
        with open(path, "w") as f:
            yaml.dump(data, f, sort_keys=False, indent=2)
    except Exception as exc:
        raise YamlFileError(f"Error: {exc}")


def get_nested_item(data: Dict[str, Any], path: str) -> Any:
    keys = path.split(".")
    for key in keys:
        if not isinstance(data, dict) or key not in data:
            return None
        data = data[key]
    return data


def set_nested_item(data: Dict[str, Any], path: str, value: Any) -> None:
    keys = path.split(".")
    current_level = data
    for key in keys[:-1]:
        if key not in current_level or not isinstance(current_level[key], dict):
            current_level[key] = {}
        current_level = current_level[key]
    current_level[keys[-1]] = value


def handle_ppa_update(args: argparse.Namespace, data: Dict[str, Any]) -> None:
    ppa_list = get_nested_item(data, args.path)
    if ppa_list is None:
        raise ValueError(
            f"Path '{args.path}' not found in the YAML file. Nothing to update."
        )
    for ppa in ppa_list:
        if ppa.get("name") == args.name:
            if args.auth is not None:
                ppa["auth"] = args.auth
            if args.fingerprint is not None:
                ppa["fingerprint"] = args.fingerprint
            if args.keep_enabled is not None:
                ppa["keep-enabled"] = args.keep_enabled
            break
    else:
        raise ValueError(
            f"PPA with name '{args.name}' not found under '{args.path}'. Nothing to update."
        )
    save_yaml_file(args.image_definition_file, data)
    logging.info(
        f"Successfully updated PPA '{args.name}' in '{args.image_definition_file}'."
    )


def handle_ppa_add(args: argparse.Namespace, data: Dict[str, Any]) -> None:
    ppa_list = get_nested_item(data, args.path)
    if ppa_list is None:
        logging.info(f"Path '{args.path}' not found. Creating it.")
        ppa_list = []
        set_nested_item(data, args.path, ppa_list)
    for ppa in ppa_list:
        if ppa.get("name") == args.name:
            raise ValueError(
                f"PPA with name '{args.name}' already exists. Use 'update' to modify."
            )
    new_ppa = {
        "name": args.name,
        "auth": args.auth,
        "fingerprint": args.fingerprint,
        "keep-enabled": args.keep_enabled,
    }
    ppa_list.append(new_ppa)
    save_yaml_file(args.image_definition_file, data)
    logging.info(
        f"Successfully added PPA '{args.name}' to '{args.image_definition_file}'."
    )


def handle_ppa_remove(args: argparse.Namespace, data: Dict[str, Any]) -> None:
    ppa_list = get_nested_item(data, args.path)
    if ppa_list is None:
        logging.warning(f"Path '{args.path}' not found. Nothing to remove.")
        return
    new_ppa_list = [ppa for ppa in ppa_list if ppa.get("name") != args.name]
    if len(new_ppa_list) == len(ppa_list):
        logging.warning(f"PPA with name '{args.name}' not found. Nothing removed.")
        return
    set_nested_item(data, args.path, new_ppa_list)
    save_yaml_file(args.image_definition_file, data)
    logging.info(
        f"Successfully removed PPA '{args.name}' from '{args.image_definition_file}'."
    )


def handle_generic_update(args: argparse.Namespace, data: Dict[str, Any]) -> None:
    set_nested_item(data, args.path, args.value)
    save_yaml_file(args.image_definition_file, data)
    logging.info(
        f"Successfully updated path '{args.path}' in '{args.image_definition_file}'."
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="A script to patch image definition YAML files.",
        formatter_class=argparse.RawTextHelpFormatter,
    )
    parser.add_argument(
        "path",
        help="The dot-notation path to the item (e.g., 'customization.extra-ppas').",
    )
    subparsers = parser.add_subparsers(
        dest="action", required=True, help="Action to perform"
    )

    # Sub-parser for 'update'
    parser_update = subparsers.add_parser("update", help="Update an existing item.")
    parser_update.add_argument(
        "--name", help="The name of the PPA to update (required for PPAs)."
    )
    parser_update.add_argument("--auth", help="The new auth secret for the PPA.")
    parser_update.add_argument(
        "--fingerprint", help="The new GPG fingerprint for the PPA."
    )
    parser_update.add_argument(
        "--keep-enabled",
        type=lambda x: (str(x).lower() == "true"),
        help="Set if the PPA should be kept enabled.",
    )
    parser_update.add_argument(
        "--value", help="The new value for a simple key-value pair."
    )

    # Sub-parser for 'add'
    parser_add = subparsers.add_parser("add", help="Add a new item.")
    parser_add.add_argument("--name", required=True, help="The name of the PPA to add.")
    parser_add.add_argument(
        "--auth", required=True, help="The auth secret for the PPA."
    )
    parser_add.add_argument(
        "--fingerprint", required=True, help="The GPG fingerprint for the PPA."
    )
    parser_add.add_argument(
        "--keep-enabled",
        type=lambda x: (str(x).lower() == "true"),
        default=True,
        help="Whether the PPA should be kept enabled (true/false).",
    )

    # Sub-parser for 'remove'
    parser_remove = subparsers.add_parser("remove", help="Remove an existing item.")
    parser_remove.add_argument(
        "--name", required=True, help="The name of the PPA to remove."
    )

    parser.add_argument(
        "image_definition_file", help="Path to the image definition YAML file."
    )

    args = parser.parse_args()

    if (
        args.path == "customization.extra-ppas"
        and args.action == "update"
        and not args.name
    ):
        parser.error("--name is required when updating a PPA.")

    try:
        data = load_yaml_file(args.image_definition_file)
        if args.path == "customization.extra-ppas":
            if args.action == "update":
                handle_ppa_update(args, data)
            elif args.action == "add":
                handle_ppa_add(args, data)
            elif args.action == "remove":
                handle_ppa_remove(args, data)
        else:
            if args.action == "update" and args.value is not None:
                handle_generic_update(args, data)
            else:
                raise ValueError(
                    f"Unsupported path or action combination for '{args.path}'."
                )
        sys.exit(0)
    except Exception as e:
        logging.error(e)
        sys.exit(1)


if __name__ == "__main__":
    main()
