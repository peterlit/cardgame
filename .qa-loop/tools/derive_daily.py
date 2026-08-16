#!/usr/bin/env python3
"""Derive the Causeway daily challenge for a dayIndex (or today) from data/daily-pool.json.
Mirrors ios/Causeway/Causeway/Model/Daily.swift (FROZEN rng formula). Usage: derive_daily.py [dayIndex]"""
import json, sys, datetime, os
M = 0xFFFFFFFF
class Mul:
    def __init__(s, seed): s.a = seed & M
    def next(s):
        s.a = (s.a + 0x6D2B79F5) & M
        a = s.a
        t = ((a ^ (a >> 15)) * (a | 1)) & M
        t = (t ^ ((t + (((t ^ (t >> 7)) * (t | 61)) & M)) & M)) & M
        return ((t ^ (t >> 14)) & M) / 4294967296.0
    def int(s, b): return int(s.next() * b)
SILVER_U = ["moves", "no-undo"]
SILVER_C = ["cells-le-1", "cells-le-2", "down-openers-20"]
GOLD = ["no-cells", "aces-first", "kings-first", "jacks-down-first", "suits-top-down", "suit-sprint"]
LAB = {"moves": "Win in {p} moves or fewer", "no-undo": "Win without using undo",
       "cells-le-1": "Win using a free cell at most once",
       "cells-le-2": "Win using free cells at most twice",
       "down-openers-20": "Open all four down-foundations within your first 20 moves",
       "no-cells": "Win without ever using a free cell",
       "aces-first": "Send all four Aces home before any other card",
       "kings-first": "Send all four Kings to the down-foundation before any Ace",
       "jacks-down-first": "Get every Jack onto the down-foundation before any Ace",
       "suits-top-down": "For every suit, send its King home before its Ace",
       "suit-sprint": "Finish one whole suit before any other suit is started"}
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
pool = json.load(open(os.environ.get("POOL", "/Users/plit/Documents/src/cardgame/data/daily-pool.json")))["seeds"]
sols = json.load(open(os.environ.get("SOLS", "/Users/plit/Documents/src/cardgame/data/daily-solutions.json")))["solutions"]
di = int(sys.argv[1]) if len(sys.argv) > 1 else (datetime.date.today() - datetime.date(2026, 8, 12)).days
rec = pool[di]
rng = Mul(0x9e3779b9 ^ (di + 1))
sp = SILVER_U + [x for x in SILVER_C if x in rec["supports"]]
gp = [x for x in GOLD if x in rec["supports"]]
s = sp[rng.int(len(sp))]; g = gp[rng.int(len(gp))]
par = rec["par"]; n = int(round(par * 1.2))
sol = sols.get(str(rec["seed"]), {})
print(f"dayIndex   {di}   (date {(datetime.date(2026,8,12)+datetime.timedelta(days=di)).isoformat()})")
print(f"deal       #{rec['seed']:,}   par {par}")
print(f"Bronze     Clear the deal")
print(f"Silver     {LAB[s].format(p=n)}")
print(f"Gold       {LAB[g].format(p=n)}")
print("demo pills " + " ".join(["Clear"] + (["Silver"] if sol.get("silver") else []) + (["Gold"] if sol.get("gold") else [])))
print("line len   " + ", ".join(f"{k}={len(v.split())}" for k, v in sol.items() if isinstance(v, str)))
