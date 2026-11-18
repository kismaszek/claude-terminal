# claude-terminal

Windows Terminal beállítások Claude Code-hoz: projektválasztó, indítóprofilok, ablakrész-
gyorsbillentyűk és parancspaletta-almenük, egy telepítővel.

## Miért praktikus?

Aki több projekten dolgozik Claude Code-dal, annak a napja azzal indul, hogy ablakot nyit,
`cd`-zik a megfelelő mappába, és elindítja a `claude`-ot. Ha egy félbehagyott munkát folytatna,
azt is tudnia kell, melyik mappában volt és milyen kapcsolóval. Ez a csomag ezt egy
billentyűre vagy egy listaválasztásra rövidíti:

- **Asztali ikon, és ott folytatod, ahol abbahagytad.** A „Claude projektek” ikon megkérdezi:
  új munka (projektválasztó), vagy az előző munkamenet folytatása. Folytatáskor az előző
  munkamenet minden projektje külön fülön nyílik meg, és mindegyikben a Claude az utolsó
  beszélgetést folytatja.
- **Egy billentyű, és a projektben vagy.** `Ctrl+Shift+3` megnyitja a projektlistát. Egy szám,
  és az adott mappában már fut is a Claude. A legutóbb használt mappák maguktól kerülnek fel.
- **Folytatás egy lépésben.** `c2` a 2. projekt utolsó sessionjét folytatja, `r2` a korábbiak
  közül választ. Nem kell emlékezni, hol tartottál.
- **Több projekt egymás mellett.** `Alt+Shift+V` / `H` új ablakrészt nyit (a fül kettéosztva),
  ugyanezzel a választóval. Egy ablakrész kinagyítható, új fülre vagy ablakba tehető, és vissza
  is rakható.
- **Képernyőkép egy gombbal.** `Alt+S`, kiválasztod a monitort (vagy egy területet), és a kép
  már bent is van a Claude beviteli sorában, csak a kérdést kell mellé írni.
- **Súgó a választó alján.** A választó parancsai és a Terminal billentyűi (képernyőkép,
  ablakrészek) egy pillantással átláthatók, nem kell fejben tartani őket.
- **Minden a parancspalettáról is megy.** `Ctrl+Shift+P`, beírod, hogy „claude”, és a projektre
  gépelve indíthatsz, folytathatsz, vagy a listát kezelheted.
- **Rendezett Terminal.** Az új indítás a meglévő ablak új fülén nyílik, a Claude-fülek színesek,
  és az ikonjuk is mutatja, melyik melyik.
- **Egyszerű telepítés.** Egy dupla kattintás, hálózat nélkül is működik. A meglévő Terminal-
  beállításokhoz nem nyúl, és előtte mentést készít.

## Hogyan néz ki

- **Projektválasztó** (`Ctrl+Shift+3`): fent a rögzített projektek, alattuk a legutóbb
  használtak dátummal. Az egyforma nevű mappák a szülőmappájukkal különülnek el.
- **Több session egy ablakban:** egy fülön több ablakrész (a fül kettéosztott részei),
  mindegyikben külön projekt Claude-ja, egymástól függetlenül. Új ablakrész: `Alt+Shift+V`
  (jobbra) / `H` (lefelé), és benne ugyanez a választó jön fel. Váltás: `Alt+nyilak`, méretezés:
  `Alt+Shift+nyilak`, bezárás: `Ctrl+Shift+W`.
- **Ablakrészek kezelése:** nagyítás (`Alt+Shift+Z`), áthelyezés új fülre (`Alt+Shift+T`) vagy új
  ablakba (`Alt+Shift+N`), vissza egy meglévő fülre `Alt+Shift+1…9`-cel. A futó session nem szakad meg.
- **Parancspaletta** (`Ctrl+Shift+P`, „claude”): indítás új fülön vagy ablakrészben, folytatás,
  korábbi session, listakezelés (átnevezés, rögzítés, törlés, új mappa).
- **Új fül menü** (a `+` melletti lenyíló): a három Claude-profil legfelül.

## Telepítés

Előfeltétel: Windows Terminal (legalább egyszer elindítva), PowerShell 7 (`pwsh`) és a `claude`
parancs. Ha valamelyik hiányzik, a telepítő megmondja, hogyan pótolható.

**A legegyszerűbb, ha már használsz Claude Code-ot:** írd be neki ezt:

```
Telepítsd fel nekem: https://github.com/kismaszek/claude-terminal
```

A Claude letölti, megkérdezi a két munkamappát, és lefuttatja a telepítőt.

> **Claude-nak szóló telepítési útmutató:**
> 1. Klónozd a repót a `$env:USERPROFILE\claude-terminal` mappába. Ha ott már van klón, ahelyett
>    `git pull`.
> 2. Kérdezd meg a felhasználótól a Céges és a Magán profil munkamappáját. Javaslat: Céges =
>    `D:\CLAUDE`, ha létezik, különben a felhasználói mappa; Magán = `~\claude-workspace`, ha
>    létezik. A `-` azt jelenti, hogy az a profil ne legyen.
> 3. Futtasd: `pwsh -NoProfile -File $env:USERPROFILE\claude-terminal\install.ps1 -Ceges <mappa>
>    -Magan <mappa|->`. Ha a felhasználó később újra akarja kérdeztetni, akkor `-Ujrakonfig`.
> 4. Ha a telepítő előfeltételt hiányol, mondd el a felhasználónak, mit és hogyan kell pótolnia,
>    és a pótlás után futtasd újra.
> 5. A végén mondd el a telepítő kimenetét, és hogy a `Ctrl+Shift+3` vagy az asztali „Claude
>    projektek” ikon indítja. Tool-hívásból ne indíts Windows Terminalt, mert a
>    `CLAUDE_CODE_CHILD_SESSION` öröklődne, és az ott induló Claude nem írna transcriptet.

**Git-klónnal** (ajánlott, így a frissítés egy `git pull`):

```powershell
git clone https://github.com/kismaszek/claude-terminal.git $env:USERPROFILE\claude-terminal
pwsh -File $env:USERPROFILE\claude-terminal\install.ps1
```

Ilyenkor helyben telepít, a profilok a klónra mutatnak. A menü szkriptjének változása a
`git pull` után azonnal él, a `wt-claude.json` változása után az `install.ps1`-et újra kell
futtatni.

**Frissítés-jelzés:** a Claude-profilok indulásakor a szkript a háttérben `git fetch`-et futtat
(legfeljebb 3 mp-et vár rá, ha a szerver nem érhető el, nem akad meg). Ha a távoli ág előrébb
jár, a választó kiírja az új commitokat, és az `u` lefuttatja a `git pull`-t és az
`install.ps1`-et, majd újraindul. A Céges/Magán profil csak egy sort ír ki, és nem vár a
fetch-re (az előző indításkori eredményt mutatja).

**Offline, csomagból:** a GitHubon *Code → Download ZIP*, vagy a mappa átmásolása pendrive-on
vagy megosztón. Kibontás után dupla kattintás a `telepites.cmd`-re. A fájlok a
`%LOCALAPPDATA%\claude-terminal` mappába kerülnek, a letöltés utána törölhető. Frissítés: új
csomag, és ugyanúgy `telepites.cmd`.

**Első telepítéskor** a telepítő megkérdezi a gép két munkamappáját, a Céges és a Magán profilét
(Enter = a javaslat, `-` = az a profil ne legyen). A válaszokat a `gep.json`-ban jegyzi meg,
újrakérdezés: `-Ujrakonfig`.

**Asztali ikon:** a telepítő létrehozza az asztalon a „Claude projektek” parancsikont (kihagyás:
`-NincsIkon`). Indításkor:

```
  Claude – indítás

   1) Új munka: projektválasztó
   2) Előző munkamenet folytatása (bezárva 2026-11-11 12:42, 3 projekt):
        1. Weboldal  D:\Projektek\weboldal
        2. Okosotthon  D:\Projektek\okosotthon
        3. Jegyzetek  D:\Projektek\jegyzetek

  Választás (Enter = 1)
```

A `2` után megkérdezi, melyiket folytassa (Enter = mind, vagy sorszámok, pl. `1,3`). Az első
projekt az aktuális fülön, a többi új fülön indul ugyanabban az ablakban, mindegyik
`claude --continue`-val. Ha az előző munkamenet üres (első használat), rögtön a projektválasztó
jön.

**Mi az előző munkamenet:** minden Claude-fül (menü, paletta, Céges/Magán profil,
visszaállítás) futás közben jelzőfájlt tart a `munkamenetek\` mappában (gépenkénti, nincs
verziózva), és 20 másodpercenként frissíti. Ha a Claude szabályosan kilép, a jelző törlődik. Ha
viszont a fület vagy az ablakot bezárják, vagy a gép leáll, a jelző megmarad, és az utolsó
frissítése megmutatja, mikor szűnt meg a fül. A fül a bezárás pillanatában meg is jelöli a
jelzőjét, mert a Windows a bezárt folyamatot még néhány másodpercig életben hagyja; így a
bezárás után azonnal indított ablak is felkínálja a visszaállítást. Az előző munkamenet a legutóbb, egyszerre (90
másodpercen belül) megszűnt fülek köre. A korábban, külön bezárt fülek és a még futó fülek nem
kerülnek bele. Visszaállítás után a régi jelzők törlődnek. Az „Új munka” választás megtartja
őket, így a visszaállítás később is elérhető marad.

A telepítő a `wt-claude.json` alapján fésüli bele a Terminal `settings.json`-jába a
beállításokat, és előtte mentést készít (`settings.json.bak-<időbélyeg>`). Többször is
futtatható. A profilokat guid, az actionöket id szerint cseréli, a gyorsbillentyűknél az azonos
billentyűn ülő más hozzárendelést törli. `-WhatIf`: csak kiírja, mit csinálna.

## Gyorsbillentyűk és parancsok

| Billentyű / hely | Mit csinál |
|---|---|
| `Ctrl+Shift+1` | Céges Claude új fülön (a gép céges munkamappájában) |
| `Ctrl+Shift+2` | Magán Claude új fülön (a gép magán munkamappájában) |
| `Ctrl+Shift+3` | Claude – projekt: a választó menü |
| `Alt+Shift+V` / `H` / `D` | új ablakrész jobbra / lefelé / automatikusan, a választó menüvel |
| `Alt+Shift+Z` | ablakrész nagyítása / vissza |
| `Alt+Shift+T` / `N` | ablakrész áthelyezése új fülre / új ablakba |
| `Alt+Shift+1…9` | ablakrész áthelyezése az 1–9. fülre |
| `Alt+S` | képernyőkép a Claude-nak: monitor / összes / terület / utolsó kép választása (lásd lent) |
| `Ctrl+Shift+P` → „claude” | Claude: projekt új fülön / új ablakrészben / folytatása / korábbi sessionje, projektlista kezelése |
| `Alt+Shift+-` / `Alt+Shift+=` | az aktuális ablakrész duplikálása lefelé / jobbra (a Terminal alapja, változatlan) |

A választó a projektlista alatt a saját parancsait és a Terminal fenti billentyűit is mutatja
(„Billentyűk”: képernyőkép, ablakrészek), hogy ne kelljen fejben tartani őket.

**Ablakrész** = a fül egy kettéosztott része (a Windows Terminalban „pane”): egy fülön belül több
egymás melletti vagy alatti terület, mindegyikben külön session.

**A választó menü parancsai:**

| Beírás | Mit csinál |
|---|---|
| `3` | Claude indítása a 3. projektben (Enter = az 1.) |
| útvonal | Claude indítása abban a mappában |
| `c3` / `r3` | a 3. projekt utolsó sessionjének folytatása / korábbi session választása |
| `+` / `+C:\mappa` | új mappa rögzítése (nevet kér) |
| `+3` | a 3. tétel rögzítése (pl. egy legutóbb használt) |
| `a3` | a 3. tétel átnevezése |
| `-3` | a 3. tétel törlése (legutóbb használtnál: elrejtése) |
| `m5 1` | az 5. tétel áthelyezése az 1. helyre (`m5` = rákérdez a helyre) |
| `f3` | a 3. tétel fix sorszámot kap (mindig a 3. marad); újra `f3` = a fixálás levétele |
| `k <név>` | mappa keresése név szerint (kis/nagybetű és ékezet nem számít) |
| `k` | új projektmappák felderítése: `.git`, `CLAUDE.md` vagy `.claude` van bennük, és még nincsenek a listán |
| `u` | frissítés, ha a választó jelzi, hogy a repóban új commit van |
| `q` | kilépés, marad a PowerShell |

**Képernyőkép (`Alt+S`):** a Claude-ablakrész alatt egy kis választó nyílik. `1`…`9` = az adott
monitor (balról jobbra; a Terminal monitorát jelöli), `a` = az összes monitor egyben, `t` =
terület kijelölése (Win+Shift+S), `u` = a legutóbbi képernyőkép (a Win+Shift+S / PrtScn
mentési mappájából vagy a `Képek\Claude`-ból), `Esc` = mégse. A választás után a választó bezárul,
a kép a vágólapra kerül, és egy rejtett segédfolyamat `Alt+V`-t küld a Terminalnak, amitől a
Claude Code beilleszti (`[Image #1]`). Ha a választott monitoron van a Terminal, a kép idejére
lekicsinyül, hogy ne takarja ki a tartalmat. A monitorképek a `Képek\Claude` mappába is
mentődnek. Hiba esetén a részletek a repó `kepernyokep.log` fájljában vannak; ha a beillesztés
elmarad (pl. közben máshová kattintottál), a kép a vágólapon van, `Alt+V`-vel kézzel is
beilleszthető.

Globális beállítás (`wt-claude.json` → `globals`): `windowingBehavior: useAnyExisting`, vagyis
egy új Terminal-indítás (parancsikon, `wt`, Start menü) a meglévő ablak új fülén nyílik meg.

`defaultProfile`: a „Claude – projekt” profil, így a fülsáv **+** gombja (és a Ctrl+Shift+T, valamint
a sima `wt` / Start menüs indítás) a projektválasztót nyitja. Sima PowerShellhez a + melletti
lenyíló menüből kell választani.

Minden Claude-indítás előtt törlődik a `CLAUDE_CODE_CHILD_SESSION` és a `NO_COLOR` változó.
Ha egy Terminal-ablakot egy Claude-session tool-hívása indított, ezek öröklődnek, és ilyenkor a
session nem ír transcriptet (a `--resume` nem látja), és fekete-fehér lesz.

## Projektlista

- **Gépenkénti:** a `claude-projektek.txt` a gép saját listája, a repóba nem kerül. Ha még
  nincs, a `claude-projektek.minta.txt`-ből készül. Formátum: `Név | Útvonal`, `#` = megjegyzés,
  `! útvonal` = elrejtett mappa, `[3] Név | Útvonal` = fix sorszámú tétel. A nem létező útvonalak
  kimaradnak.
- **Sorrend:** a fix tételek mindig a saját sorszámukon állnak. A többi tétel a maradék helyeket
  tölti ki: elöl a rögzítettek a fájlbeli sorrendjükben, utánuk a legutóbb használtak a használat
  ideje szerint. Ha egy fix sorszám nagyobb a lista hosszánál, a tétel a lista végére kerül.
- **Áthelyezés (`m<szám> <hely>`):** fix tételnél a fix sorszámot állítja át, és ha a célhelyen
  másik fix tétel áll, a kettő helyet cserél. Rögzített tételnél a rögzítettek sorrendjét
  módosítja; fix tétel helyére nem tehető. Legutóbb használt tételt előbb rögzít. A legutóbb
  használtak közé nem tehető tétel, ilyenkor a rögzítettek végére kerül.
- **Fix sorszám (`f<szám>`):** a tétel a mostani helyén marad. Legutóbb használt tételt ehhez
  rögzít is. A levétele után a tétel rögzített marad.
- **Legutóbb használt mappák:** a `~/.claude/projects` alapján, a legfrissebbel kezdve,
  legfeljebb 15.
- **Átnevezés:** legutóbb használt tétel átnevezésekor a mappa az új névvel a rögzítettek közé
  kerül, mert név csak ott tárolható.
- **Törlés:** rögzített tételnél kiveszi a sort. Legutóbb használt tételnél egy `! <útvonal>` sort
  ír, ettől a mappa nem jelenik meg többé. Visszahozás: `+<útvonal>`.
- **Keresés (`k`):** a fix meghajtókon és a felhasználói mappában keres, legfeljebb 4 szint
  mélyen, 15 mp-ig. A rendszermappákat (`Windows`, `Program Files`, `AppData`…) és a
  build-/függőségmappákat (`node_modules`, `bin`, `obj`…) kihagyja. A találatok közül szám =
  Claude indítása ott, `+<szám>` = rögzítés a listára. A parancspalettán: projektlista
  kezelése → Projektmappa keresése…

A paletta-almenüket a választó minden indításkor frissíti (csak ha változott). Kézzel:

```powershell
pwsh $env:USERPROFILE\claude-terminal\claude-projekt.ps1 -CsakPaletta
```

## Verziózás

A verziószám a `VERSION` fájlban van (SemVer: fő.al.javítás), a változások a `CHANGELOG.md`-ben.
A telepítő és a menü fejléce kiírja az aktuális verziót, a frissítés-jelzés pedig a régit és az
újat is (pl. `v1.0.0 → v1.1.0`).

**Kiadás:** a `VERSION` emelése, új szakasz a `CHANGELOG.md` tetején, commit a `main`-re, majd
annotált tag és push:

```powershell
git tag -a v1.2.1 -m "1.2.1"
git push origin main --follow-tags
```

Kisebb commit (pl. README-javítás) verzióemelés nélkül is mehet. Ilyenkor a frissítés-jelzés csak
a commitok számát mutatja.

## Testreszabás

- Munkamappák: `install.ps1 -Ujrakonfig`, vagy `install.ps1 -Ceges <mappa> -Magan <mappa|->`.
- Profil, action, billentyű, globális beállítás: a `wt-claude.json`-ban, utána `install.ps1`. Ne
  közvetlenül a Terminal `settings.json`-jában, mert a következő telepítés felülírja.

## Licenc

MIT, lásd a [LICENSE](LICENSE) fájlt: szabadon használható, módosítható és továbbadható, a
szerzői sor megtartásával, garancia nélkül.
