"""Shared door dimensions for static facade exports and native visits."""

import json
from pathlib import Path


CATALOG = Path(__file__).resolve().parents[2] / "godot/data/campus_visits.json"
VISITS = {
    site["asset"]: site
    for site in json.loads(CATALOG.read_text(encoding="utf-8"))
} if CATALOG.is_file() else {}
MATERIALS = {
    "VisitGlass": ((.35, .46, .45), .23, .18),
    "VisitWood": ((.24, .058, .078), .68, 0),
}


def door_spans(site, length):
    for door in site["doors"]:
        center = length * (.5 + site.get("offset",0) + door["offset"])
        half = length * door["span"] * .5
        yield center - half, center + half, door


def walkable_glazing(front, start, end, top, depth, step, finish, frame):
    site = VISITS[front.name]
    bottom = site["floor"]

    def glass(a, b, low, high):
        if b <= a or high <= low:
            return
        front.member(a, b, low, high, depth - .017, depth + .009, finish)
        for i in range(1, round((b - a) / step)):
            s = a + step * i
            if s < b - .10:
                front.member(s - .024, s + .024, low, high, depth+.006, depth+.073, frame)

    cursor = start
    for a, b, door in door_spans(site, front.length):
        if a < start or b > end:
            continue
        glass(cursor, a, bottom, top)
        door_top = bottom + door["height"]
        glass(a, b, door_top, top)
        for edge in (a, b):
            front.member(edge-.028, edge+.028, bottom, top, depth-.049, depth+.063, frame)
        d = door["outset"]
        front.member(a+.011,b-.011,bottom+.022,door_top-.017,d-.027,d+.027,"VisitGlass")
        cursor = b
    glass(cursor, end, bottom, top)
    for y in (top, bottom + site["doors"][0]["height"]):
        front.member(start,end,y-.025,y+.029,depth-.029,depth+.063,frame)
