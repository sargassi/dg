# Manuale — Importazione Movimenti Magazzino da Excel

Guida all'uso della pagina **Magazzino → Import** (percorso `/inventories/import`).

Questa importazione consente di registrare **movimenti di magazzino in massa** — carichi (entrate, **IN**) e uscite (scarichi, **OUT**) — a partire da un file Excel. Il file viene letto riga per riga: ogni riga valida diventa un dettaglio del movimento (un unico carico o un'unica uscita), e lo **stock** dei relativi articoli viene aggiornato di conseguenza.

## Prerequisiti

- Avere il permesso **Gestione Magazzino** (`manage_inventory`).
- Disporre di un file Excel leggibile dal sistema (formato `.xlsx`).
- Scegliere il **tipo di operazione**: solo **Carico (IN)** o **Uscita (OUT)**. I trasferimenti tra magazzini non sono supportati da questa importazione.

> Diversamente dall'importazione Articoli, qui **non ci sono limiti** di formato o dimensione del file imposti dall'applicazione. Tieni però presente che file molto grandi richiedono qualche minuto di elaborazione (la pagina di avanzamento lo segnala).

---

## 1. Passo 1 — Caricamento del file

Nella pagina di importazione, se non ci sono dati in lavorazione, si vede il modulo di caricamento con quattro campi:

| Campo | Obbligatorio | Significato |
|---|---|---|
| **File Excel** | Sì | Il file con le righe di movimento |
| **Magazzino** | No | Magazzino da assegnare a tutte le righe. La voce predefinita **"Usa dove: (da file)"** legge il magazzino dalla colonna `dove` del file |
| **Ubicazione** | No | Ubicazione da assegnare a tutte le righe. La voce predefinita **"Nessuna ubicazione"** lascia l'ubicazione vuota. Non esiste una colonna ubicazione nel file: l'ubicazione può arrivare **solo** da questo menu |
| **Operazione** | Sì | Il tipo di movimento: **Carico (IN)** o **Uscita (OUT)** |

Premere **"Carica"**. Il file viene caricato in cache e l'elaborazione parte **in background**: si viene portati alla pagina di avanzamento, che aggiorna automaticamente la barra di stato. Quando l'analisi termina, il sistema porta all'**anteprima**.

### Colonne riconosciute nel file

| Colonna | Cosa contiene |
|---|---|
| `Item Code:` (o `itemcode` / `Item Code`) | **Codice articolo** — obbligatorio; usato per trovare l'articolo nel catalogo |
| `Fabric code:` / `Fabricode` / `Fabric Code` | Codice tessuto — aiuta a identificare l'articolo |
| `var. code:` / `Var` / `Var Code` | Codice variante — aiuta a identificare l'articolo |
| `Description:` | Descrizione (usata solo per la creazione articoli mancanti) |
| `Qt.` / `Quantity` / `QTA` / `qtyavailable` | **Quantità** del movimento |
| `Tg.`, `fabric:`, `colour:`, `materiale` | Caratteristiche (usate solo per la creazione articoli mancanti) |
| `dove` | **Codice magazzino**: usato se non è stato scelto un magazzino nel modulo |
| `Note:` | **Nome collezione** (usata per la creazione articoli mancanti) |

L'intestazione viene **riconosciuta automaticamente**: il sistema cerca la riga che contiene almeno due delle colonne note, quindi tratta tutte le righe successive come dati.

---

## 2. Passo 2 — Anteprima

Al termine dell'elaborazione appare l'anteprima con i dati letti dal file.

### Conteggi in alto

- **Righe totali**: numero di righe lette.
- **Valide**: righe in cui l'articolo è stato trovato nel catalogo.
- **Non valide** (editabile): righe scartate, raggruppate per motivo dell'errore, con il conteggio dei **codici articolo mancanti**. Motivi possibili:
  - `Item code mancante` — la riga non ha un codice articolo.
  - `Articolo <codice> / <tessuto> / <variante> non trovato` — il codice non corrisponde a nessun articolo del catalogo.
- **Nuovi WH**: numero di **magazzini nuovi** che verranno creati automaticamente (codici `dove` non presenti nel sistema).
- **Nuove coll.**: numero di **collezioni nuove** individuate dalla colonna `Note:`.

### Riepilogo

Il pannello **"Riepilogo"** elenca, con le righe associate, i **magazzini**, le **ubicazioni** e le **collezioni** coinvolte; i nuovi vengono evidenziati con l'etichetta **[NUOVO]**.

> Attenzione: magazzini e collezioni nuovi vengono **creati subito durante l'analisi**, anche se poi si annulla l'importazione. Un'anteprima annullata lascia comunque i magazzini/collezioni creati.

### Tabella delle righe

Il pannello **"Righe"** mostra la tabella completa, **in sola lettura** (non è possibile modificare i valori, solo eliminare la riga):

- Riga **rossa**: riga **non valida** (sarà saltata in fase di conferma).
- Colonna di stato: **✓ verde** = articolo trovato; **✗ rossa** = riga non valida (il motivo è nella descrizione del simbolo).
- **Quantità 0** (colonne `Qt.`/`Quantity`/`QTA`/`qtyavailable`): evidenziata in rosso — tali righe vengono **saltate** al momento dell'importazione.
- Il **codice articolo** è un collegamento allo storico movimenti di quel codice (si apre in una nuova scheda).
- Il pulsante **cestino** elimina la riga dall'importazione.

### Azioni disponibili

- **Vai alla verifica**: apre la schermata di conferma.
- **Crea N articoli mancanti** (visibile solo se esistono righe non valide con un codice articolo): crea al volo gli articoli mancanti nel catalogo e **ri-etichetta le righe** come valide (vedi sezione 4).
- **Annulla**: scarta l'importazione.

---

## 3. Passo 3 — Verifica e conferma

La pagina di verifica riepiloga la situazione prima dell'importazione:

- **Importate**: conteggio delle righe valide, con magazzini/collezioni esistenti e nuovi.
- **Saltate**: righe non valide raggruppate per errore, con la tabella dettagliata (Riga / Articolo / Errore).

Qui vale un punto importante: **le righe non valide vengono semplicemente saltate** — non bloccano la conferma. Il pulsante mostra solo il conteggio delle righe che verranno effettivamente importate ("Conferma importazione (N righe)"): controlla sempre il pannello "Saltate" prima di procedere.

Premendo **"Conferma importazione"** il sistema:

1. Crea **un unico movimento** (un `Itemin` per i carichi, un `Itemout` per le uscite) datato oggi, con nota "Importazione Excel".
2. Per ogni riga valida con **quantità maggiore di 0**, aggiunge un dettaglio con articolo, quantità, magazzino, ubicazione, collezione e tipo operazione.
3. Registra le righe **IN** come carico (operazione di tipo 1) e le righe **OUT** come uscita (operazione di tipo 2).
4. Aggiorna lo **stock**: somma la quantità per i carichi, la sottrae per le uscite.
5. Salva la **log di importazione** nello storico e porta alla pagina di riepilogo.

### Casi che possono far fallire tutta l'importazione

- **Stock negativo**: una **uscita** che porterebbe la giacenza di un articolo sotto zero fa **fallire l'intera importazione** (nessun salvataggio parziale), con errore "Stock negativo per <gencode>".
- **Nessun dettaglio**: se tutte le righe sono non valide o con quantità 0, il movimento non può essere creato ("Deve esserci almeno un dettaglio") e l'importazione risulta fallita.
- **Magazzino non specificato**: una riga valida senza magazzino (né dal menu né dalla colonna `dove`) viene scartata con "Magazzino non specificato".

---

## 4. Creazione articoli mancanti

Il pulsante **"Crea N articoli mancanti"** è un'opzione per sistemare le righe non valide senza uscire dal flusso:

1. Il sistema prende le righe non valide che hanno un **codice articolo** e le raggruppa per `codice + tessuto + variante` (righe uguali creano un solo articolo).
2. Per ciascun gruppo crea un **nuovo articolo** nel catalogo, usando:
   - la **collezione** dalla colonna `Note:` (se vuota, la creazione fallisce con "Collection mancante");
   - descrizione, taglia, tessuto, colore e materiale dalle rispettive colonne.
3. Le righe che prima erano "non trovato" vengono **ri-validate e rietichettate come valide** in anteprima.

Torna utile quando il file contiene articoli non ancora inseriti nel catalogo: li crea e li rende importabili in un colpo solo.

---

## 5. Riepilogo finale

La pagina di riepilogo mostra l'esito:

- **Righe processate** / **Importate** / **Saltate (QTA 0)** / **Non valide** / **Errori**.
- Stato: **Importazione completata** (verde), **Nessun articolo importato** (ambra) oppure **Importazione fallita** (rosso).
- Tabelle con gli articoli importati, quelli saltati e i dettagli degli errori.
- Se ci sono righe non importate, è disponibile il download **"Scarica righe non importate (XLSX)"** (`righe_non_importate.xlsx`, con Riga / Articolo / Errore) per correggerle e reimportarle.

Da qui puoi tornare ai **movimenti** o allo **storico importazioni** per consultare la log.

---

## 6. Casi particolari e consigli

- **Solo IN e OUT**: il tipo operazione deve essere Carico o Uscita; altre operazioni non vengono elaborate.
- **Quantità 0**: le righe con quantità 0 sono **saltate**, non bloccano nulla.
- **Magazzini e collezioni nuovi**: vengono creati automaticamente durante l'analisi (codice `dove` sconosciuto → nuovo magazzino; nome `Note:` sconosciuto → nuova collezione). Annullare dopo l'analisi non rimuove questi record.
- **Ubicazione solo dal modulo**: non c'è colonna ubicazione nel file; per assegnarne una usa il menu "Ubicazione" al caricamento.
- **Uscite e giacenze**: un'uscita che esaurisce lo stock (negativo) fa fallire l'intera importazione: verifica prima le giacenze dei codici in uscita.
- **Timeout**: i dati dell'anteprima restano disponibili per **30 minuti**; oltre questo tempo è necessario ricaricare il file.

---

*Flusso tecnico di riferimento: `context/flows/inventories_flow.md`.*