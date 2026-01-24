import os
import urllib.request
import xml.etree.ElementTree as ET

XML_URL = "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/ReflectionMetadata.xml"
TARGET_FILE = "src/Client/Explorer/ExplorerOrder.luau"


def main():
    print(f"Fetching Metadata from: {XML_URL}")

    try:
        with urllib.request.urlopen(XML_URL) as response:
            xml_content = response.read()
    except Exception as e:
        print(f"Failed to download XML: {e}")
        exit(1)

    try:
        root = ET.fromstring(xml_content)
    except ET.ParseError as e:
        print(f"Failed to parse XML: {e}")
        exit(1)

    explorer_orders = {}

    for item in root.findall(".//Item[@class='ReflectionMetadataClass']"):
        properties = item.find("Properties")
        if properties is None:
            continue

        name_elem = properties.find("string[@name='Name']")
        order_elem = properties.find("string[@name='ExplorerOrder']")

        if (
            name_elem is not None
            and name_elem.text is not None
            and order_elem is not None
            and order_elem.text is not None
        ):
            class_name = name_elem.text
            try:
                order_val = int(order_elem.text)
                explorer_orders[class_name] = order_val
            except (ValueError, TypeError):
                continue

    if not explorer_orders:
        print("No ExplorerOrder data found in the XML.")
        exit(1)

    sorted_items = sorted(explorer_orders.items())

    table_entries = [f"{name}={order}" for name, order in sorted_items]
    file_content = "--stylua: ignore\nreturn {" + ",".join(table_entries) + "}\n"

    os.makedirs(os.path.dirname(TARGET_FILE), exist_ok=True)

    with open(TARGET_FILE, "w", encoding="utf-8") as f:
        f.write(file_content)

    print(f"Successfully wrote {len(explorer_orders)} entries to {TARGET_FILE}")


if __name__ == "__main__":
    main()
