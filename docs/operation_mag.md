# Manuale — Operazioni di Magazzino (App)

Guida all'uso delle tre schermate operative del magazzino:

| Schermata | Percorso | Operazione |
|---|---|---|
| **Carico (IN)** | `/app/in_warehouse` | Entrata merce in magazzino |
| **Scarico (OUT)** | `/app/out_warehouse` | Uscita merce dal magazzino |
| **Variazione (Spostamento)** | `/app/move_products` | Trasferimento tra magazzini/ubicazioni |

Sono i tre movimenti base del magazzino. Ogni operazione registra un movimento nello **storico** e aggiorna **le giacenze** (StockLevel): i carichi aumentano la giacenza, gli scarichi la diminuiscono, le variazioni la spostano da un'origine a una destinazione.

> Le schermate si adattano al dispositivo: su **mobile** i moduli sono impilati in una colonna centrata, su **desktop** sono organizzati in una griglia più ampia. Le funzioni sono le stesse.

> In tutte le pagine di Magazzino (incluse queste tre) la **barra di navigazione** in alto offre il collegamento rapido alle operazioni **Carico**, **Scarico** e **Variazione**, oltre a **Movimenti** (lo storico) e alle altre sezioni del magazzino. La voce della pagina corrente è evidenziata.

---

## 1. Prerequisiti

- Avere il permesso **Gestione Magazzino** (`manage_inventory`).
- L'accesso avviene dal menu **Magazzino** della dashboard (App → Magazzino → **Aggiunta a Magazzino**, **Uscita da Magazzino**, **Variazione Magazzino**).

---

## 2. Elementi comuni alle tre schermate

### Intestazione del movimento

Ogni operazione ha una **Data** (precompilata con data del giorno corrente) e un campo **Note** (facoltativo).

### Dove (magazzino e ubicazione)

Per **Carico** e **Scarico** c'è un'unica coppia **Magazzino + Ubicazione**:

- Il menu **Magazzino** elenca i magazzini disponibili.
- Il menu **Ubica** si attiva solo dopo aver scelto il magazzino: mostra le **ubicazioni di quel magazzino** (rimane disabilitato con "Seleziona prima il magazzino" finché non scegli il magazzino).
- Il pulsante **QR** (icona scanner) apre la fotocamera per **scansionare il QR** di un magazzino o di un'ubicazione e compilare i campi automaticamente.

Per **Variazione** ci sono **due coppie**: il pannello **Da** (origine) e il pannello **A** (destinazione), entrambi con magazzino + ubicazione e relativo scanner QR.

### Dettaglio del movimento (righe articolo)

La tabella dei dettagli elenca gli articoli del movimento. Ogni riga ha:

- **Codice articolo**: campo di testo con **autocompletamento**. Scrivi il codice (anche parziale) e scegli l'articolo dalla lista che appare; oppure premi il pulsante **QR** per scansionare il codice dell'articolo.
- **Q.tà**: la quantità del movimento (minimo 1).
- **Cestino**: rimuove la riga.

Sotto la tabella il pulsante **"Aggiungi riga"** inserisce una nuova riga vuota.

> Scegli sempre l'articolo **dall'autocompletamento** (o via QR): il sistema registra così il riferimento interno corretto. Un codice digitato ma non riconosciuto rende la riga non valida.

### Pulsanti finali

- **Salva Carico / Salva Scarico / Salva Spostamento**: invia e registra il movimento.
- **Annulla**: torna alla pagina di provenienza senza salvare.

---

## 3. Carico (IN) — `/app/in_warehouse`

Registra **merce in entrata** (operazione di tipo 1). Oltre agli elementi comuni:

- Campo **Collezione** (in alto): collezione predefinita da assegnare alle righe. Se arrivi da **Seleziona Articoli**, il campo è nascosto e la collezione viene da lì.
- Una o più righe con articolo e quantità: ogni riga aggiunge **quantità alla giacenza** dell'articolo nel magazzino/ubicazione scelti.

### Partenza da Seleziona Articoli

Se entri da **Magazzino → Seleziona Articoli → Vai a Carico →**, la schermata arriva **già compilata** con gli articoli selezionati e le relative quantità. Controlla i dati e completa con magazzino/ubicazione, poi salva.

---

## 4. Scarico (OUT) — `/app/out_warehouse`

Registra **merce in uscita** (operazione di tipo 2). Rispetto al carico **non c'è il campo Collezione**.

Viene **controllata la giacenza**: se la quantità di una riga **supera la disponibilità** dell'articolo nel magazzino/ubicazione scelti, il sistema rifiuta l'operazione e mostra un messaggio del tipo:

> `GENCODE: quantità N supera la disponibilità (M pz)`

Correggi la quantità o scegli un'altra ubicazione prima di salvare.

---

## 5. Variazione / Spostamento — `/app/move_products`

Trasferisce merce tra magazzini/ubicazioni (operazione di tipo 3). È l'unica schermata con **origine e destinazione**:

1. Scegli **Da** (magazzino + ubicazione di origine) e **A** (magazzino + ubicazione di destinazione).
2. Inserisci le righe articolo. Ogni riga **appartiene all'origine**: il sistema mostra per ogni riga il magazzino/ubicazione di provenienza.
3. Inserisci quantità e salva.

Il sistema verifica che la quantità richiesta **non superi la giacenza** disponibile nell'origine; in caso contrario l'operazione viene rifiutata con un messaggio esplicativo.

> Le righe possono appartenere a **origini diverse** (più magazzini/ubicazioni): il sistema raggruppa e crea un movimento per ciascuna origine, tutto in un'unica operazione verso la stessa destinazione.

---

## 6. Dopo il salvataggio

Alla conferma torni alla pagina di provenienza con un avviso di successo ("Carico/Scarico/Spostamento creato con successo"). I movimenti sono visibili:

- nello **storico** di Magazzino (**Tutti i Movimenti**);
- nelle relative schermate di dettaglio/conferma con i dati completi (articolo, quantità, magazzino, ubicazione).

Lo stock viene aggiornato immediatamente: carichi e scarichi variano la giacenza, gli spostamenti la trasferiscono dall'origine alla destinazione.

---

## 7. Note e consigli

- **QR code**: puoi scansionare sia il QR di **magazzino/ubicazione** (compila i menu "Dove") sia il QR di **articolo** (compila la riga). Il lettore si apre con il pulsante icona scanner accanto ai campi.
- **Autocompletamento**: la lista risultati si filtra mentre scrivi; selezionando l'articolo si chiude la lista e la riga risulta valida.
- **Righe non valide**: una riga senza articolo riconosciuto non viene salvata. Verifica sempre che ogni riga mostri il codice corretto.
- **Giacenze**: scarichi e spostamenti controllano la disponibilità; se la quantità supera la giacenza l'operazione viene bloccata.
- **Variazioni con più origini**: in un solo spostamento puoi trasferire da più magazzini/ubicazioni verso un'unica destinazione.

---

## 8. Collegamenti

- Flusso inventari: `context/flows/inventories_flow.md`
- Seleziona articoli: `docs/seleziona_articoli_magazzino.md`