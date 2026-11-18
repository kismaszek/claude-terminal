# Változásnapló

A verziószám [SemVer](https://semver.org/lang/hu/): **fő.al.javítás**. A `VERSION` fájl a forrás,
minden kiadás egy `v<verzió>` git tag a `main`-en.

- **fő**: a meglévő telepítés kézi beavatkozást igényel (pl. új kötelező paraméter, áthelyezett fájl).
- **al**: új funkció, a frissítés egy `git pull` + `install.ps1`.
- **javítás**: hibajavítás, a működés nem változik.

## 1.2.2 – 2026-11-17

- A választó súgója a sorszámot `<sorszám>`-mal jelöli (`c<sorszám>`, `r<sorszám>`, `m<sorszám> <hely>`
  stb.), nem egy példaszámmal: a `c4` úgy hatott, mintha az lenne maga a parancs.

## 1.2.1 – 2026-11-17

- A súgó „Billentyűk” blokkja rövidebb: a fülek sora és az `Alt+nyilak` kimaradt (ezek a Terminal
  alapjai, nem ennek a csomagnak a gombjai).

## 1.2.0 – 2026-11-17

- A projektválasztó súgója a Terminal billentyűit is mutatja (képernyőkép, fülek, ablakrészek:
  létrehozás, váltás, átméretezés, nagyítás, áthelyezés, bezárás).
- „Panel” helyett mindenhol „ablakrész” (a fül egy kettéosztott része): a parancspalettán, a
  súgóban és a README-ben. A régi nevű paletta-almenüt a telepítő lecseréli.

## 1.1.0 – 2026-11-17

- Képernyőkép a Claude-nak (`Alt+S`, parancspaletta: „Claude: képernyőkép beillesztése”): monitor,
  összes monitor, terület vagy a legutóbbi képernyőkép választása, és a kép automatikus beillesztése
  a Claude beviteli sorába. A Terminal a saját monitora képéről a felvétel idejére eltűnik.

## 1.0.0 – 2026-11-12

Az első verziózott kiadás, a 2026-11-11 óta fejlesztett állapot összefoglalása.

- Céges, Magán és projektválasztó Windows Terminal-profil, gyorsbillentyűkkel, a New Tab Menu tetején.
- Projektválasztó: gépenkénti rögzített lista és a legutóbb használt mappák; új, keresés, rögzítés,
  átnevezés, törlés/elrejtés, áthelyezés, fix sorszám a menüből és a parancspalettáról is.
- Session folytatása (`--continue`) és korábbi session választása (`--resume`) a választóból és a palettáról.
- Asztali „Claude projektek” ikon: új munka, vagy az előző munkamenet (a legutóbb egyszerre bezárt
  fülek) visszaállítása.
- Frissítés-jelzés induláskor (háttér-`git fetch`), `u` = frissítés most.
- Telepítő: git-klónból vagy offline csomagból, a gép munkamappáit megkérdezi és a `gep.json`-ban
  megjegyzi; jelzi a hiányzó Terminalt és `claude`-ot.
