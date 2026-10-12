import os

from iconlib import OUT, VARIANTS, build

os.makedirs(OUT, exist_ok=True)
for i, params in enumerate(VARIANTS, start=1):
    build(params).save(os.path.join(OUT, f"icon-{i:02d}.png"))
print("generadas", len(VARIANTS), "opciones en", OUT)
