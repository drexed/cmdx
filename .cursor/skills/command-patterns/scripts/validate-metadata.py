import re
import sys
import argparse

def validate_metadata(name, folder):
    errors = []

    if not (1 <= len(name) <= 64):
        errors.append(f"NAME ERROR: '{name}' is {len(name)} characters. Must be between 1-64.")

    if not re.match(r"^[a-z0-9]+(-[a-z0-9]+)*$", name):
        errors.append(
            f"NAME ERROR: '{name}' contains invalid characters. "
            "Use only lowercase letters, numbers, and single hyphens. "
            "No consecutive hyphens, and cannot start/end with a hyphen."
        )

    target_path = f".cursor/commands/{folder}/{name}.md"

    if errors:
        print("\n".join(errors), file=sys.stderr)
        sys.exit(1)
    else:
        print(f"SUCCESS: Metadata valid. Target path: {target_path}")
        sys.exit(0)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Validate command metadata")
    parser.add_argument("--name", required=True, help="Command name (kebab-case)")
    parser.add_argument("--folder", required=True, help="Target folder (ai, pm, sd, etc.)")
    args = parser.parse_args()
    validate_metadata(args.name, args.folder)
