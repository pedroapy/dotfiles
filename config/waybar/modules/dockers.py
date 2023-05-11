from prettytable import PrettyTable
import json
import os


streamAll = os.popen("docker ps -a --format '{{.Names}}|{{.Status}}|{{.Image}}' | sed -z 's/878413961815.dkr.ecr.eu-west-1.amazonaws.com\///g'")
textAll = streamAll.read()
rowsTextAll = textAll.strip().split('\n')

streamUp = os.popen("docker ps --format '{{.Names}}|{{.Status}}|{{.Image}}'")
textUp = streamUp.read()
rowsTextUp = textUp.strip().split('\n')

x = PrettyTable()
x.field_names = ["Container", "Status", "Image"]


def cols(data: str) -> list[str]:
    return data.split('|')

x.add_rows(list(map(cols, rowsTextAll)))
x.align = "l"

# print(x.get_string())
print(json.dumps({
    "text": len(rowsTextUp),
    "tooltip": x.get_string(),
    "class": "docker"
}))
