# Manuale — Importazione Articoli da Excel

Guida all'uso della pagina **Articoli → Generale / Import** (percorso `/mainware/import`).

L'importazione consente di caricare in massa gli articoli del catalogo a partire da un file Excel (`.xlsx`). Gli articoli vengono **creati** se non esistono ancora oppure **aggiornati** se un articolo con lo stesso identificativo (gencode) è già presente nel sistema. [ **NOTA** il gencode è composto da *itemcode + fabricode + varcode + "_" + collection_id* ]

## Prerequisiti

- Avere il permesso **Gestione Mainware** (`manage_mainware`).
- Disporre di un file Excel in formato **.xlsx** (non sono accettati `.xls`, `.csv` o altri formati).

---

## 1. Il modello Excel

Sul modulo di caricamento è disponibile il link **"Scarica modello"**: scarica il file `template_import_articoli.xlsx` con l'intestazione corretta e una riga di esempio, da usare come punto di partenza.

Il sistema **riconosce automaticamente la riga di intestazione** cercando le colonne note (es. `Item Code:`, `Prezzo`, `Note:`): non è quindi necessario che l'intestazione sia nella prima riga del file, ma deve contenere almeno due colonne riconosciute. Tutte le righe successive all'intestazione vengono trattate come righe di dati.

### Colonne riconosciute

| Colonne | Cosa contiene | Note |
|---|---|---|
| `Item Code:` | Codice articolo | **Obbligatorio** — se manca la riga viene scartata |
| `Fabric code:` | Codice tessuto | Opzionale — parte del gencode |
| `var. code:` | Codice variante | Opzionale — parte del gencode |
| `Description:` | Descrizione articolo | Opzionale |
| `Tg.` | Taglia | Opzionale |
| `colour:` | Colore | Opzionale |
| `materiale` | Materiale | Opzionale |
| `Prezzo` | Prezzo unitario | Numerico; accetta la virgola come separatore decimale (`12,34` = 12.34) |
| `Prezzo showroom` | Prezzo vendita showroom | Numerico; stessa gestione di `Prezzo` |
| `Note:` | **Nome della collezione** | Vedere la sezione dedicata qui sotto |
| `dove` | Ubicazione / magazzino | Attualmente **informativa**: il valore viene letto ma non applicato all'articolo |

Le colonne non previste vengono ignorate; il confronto dell'intestazione è **insensibile alle maiuscole** (`item code:` equivale a `Item Code:`).

> Nota sui prezzi: vengono accettati anche i simboli `€`, `$`, `£` e gli spazi, che vengono rimossi automaticamente. Un prezzo **negativo** o **non numerico** fa scartare la riga con un errore. Il valore viene arrotondato a 2 decimali.

---

## 2. Passo 1 — Caricamento del file

Nella pagina di importazione, se non ci sono dati in lavorazione, si vede il modulo di caricamento:

1. Selezionare il file **.xlsx**.
2. (Facoltativo) Scegliere una **collezione** dal menu a tendina per assegnarla a tutte le righe, ignorando la colonna `Note:` del file. La voce predefinita **"Usa Note: (da file)"** lascia che la collezione venga letta dal file.
3. Premere **"Carica"**.

Durante la lettura viene mostrato un indicatore "Caricamento in corso...". Al termine il sistema carica l'anteprima e mostra un messaggio con il numero di righe lette.

---

## 3. Passo 2 — Anteprima e correzione

Dopo il caricamento viene mostrata la tabella di **anteprima**, con una riga per ogni riga del file:

- **Riga verde**: articolo **nuovo** (non esiste ancora nel sistema).
- **Riga ambra**: articolo **esistente**: la conferma **sovrascriverà** i dati dell'articolo attuale.
- **Bordo rosso** a sinistra della riga: sono presenti **errori di validazione** da correggere.
- **Colonna Collezione**: mostra il riferimento della collezione assegnata; "Nuova: ..." indica una collezione non ancora esistente; "— mancante —" indica che manca la collezione (errore).

### Modifica delle celle

Ogni cella è modificabile direttamente in tabella. Le modifiche vengono salvate al momento (basta uscire dalla cella):

- Se si modificano `Item Code:`, `Fabric code:` o `var. code:`, il **gencode** viene ricalcolato automaticamente.
- Se si modifica `Note:` (quando la colonna non è bloccata), la **collezione** viene risolta di nuovo.
- Il pulsante **cestino** a inizio riga elimina la riga dall'importazione.

### Assegnazione collezione in massa

Il pannello **"Collezione in massa"** permette di assegnare **una collezione a tutte le righe** in un colpo solo:

1. Scegliere una collezione esistente **oppure** digitare il nome di una nuova collezione.
2. Premere **"Applica a tutte le righe"**.

In questo caso la colonna `Note:` viene **bloccata** (non più modificabile) perché la collezione è forzata. Se si usa il nome di una nuova collezione, questa viene **creata subito** e assegnata a tutte le righe.

### Errori di validazione

Se sono presenti problemi, compare un riquadro rosso **"Correggi questi problemi prima di confermare"**. Le regole di validazione:

| Errore | Significato |
|---|---|
| `manca il codice articolo` | La riga non ha un valore in `Item Code:` |
| `manca la collezione` | Nessuna collezione risolvibile: la colonna `Note:` è vuota e non è stata assegnata una collezione in massa |
| `gencode duplicato` | Due o più righe generano lo stesso gencode (stessi codici + stessa collezione) |

Finché ci sono errori il pulsante **"Conferma importazione"** resta **disabilitato**.

---

## 4. La colonna `Note:` = collezione

Concetto chiave dell'importazione: il testo nella colonna **`Note:`** identifica la **collezione** a cui appartiene l'articolo.

- Il valore viene **convertito in maiuscolo** e confrontato con le collezioni esistenti.
- Se esiste già una collezione con lo stesso nome → l'articolo vi viene assegnato.
- Se non esiste → la collezione viene segnata come **NUOVA** e **creata al momento della conferma** (finché non si conferma non viene creato nulla, per evitare dati "orfani" in caso di annullamento).

---

## 5. Il gencode

Il **gencode** è l'identificativo univoco dell'articolo nel sistema. Viene calcolato come:

```
Item Code: + Fabric code: + var. code: + "_" + collezione
```

Esempio: `Item Code:` = `ABC`, `Fabric code:` = `FAB001`, `var. code:` = `01`, collezione `#7` → gencode **`ABCFAB00101_7`**.

Due articoli con gli stessi codici ma in **collezioni diverse** hanno gencodici diversi: sono quindi considerati articoli distinti. Al contrario, un gencode **già esistente** comporta **l'aggiornamento (sovrascrittura)** dell'articolo esistente: descrizione, prezzi, colore, materiale e collezione vengono sostituiti con i valori del file.

> ⚠️ **Attenzione**: se il file contiene righe con lo stesso gencode di articoli già presenti, al momento della conferma questi verranno **sovrascritti senza richiedere conferma specifica**. Il conteggio "Articoli aggiornati" nella pagina di riepilogo è l'unico segnale di questo comportamento.

---

## 6. Passo 3 — Conferma

Quando l'anteprima è corretta, premere **"Conferma importazione"**.

Appare una pagina di riepilogo con i conteggi:

- **Righe totali**: numero di righe da importare.
- **Nuovi articoli**: articoli che verranno creati.
- **Articoli aggiornati**: articoli esistenti che verranno sovrascritti.
- **Nuove anagrafiche**: elenco delle collezioni nuove che verranno create.

Dopo aver verificato, premere **"Conferma e avvia importazione"**.

A questo punto il sistema:
1. **Crea le nuove collezioni** (se presenti).
2. Registra la **log di importazione** nello storico.
3. **Avvia l'elaborazione in background** e mostra la pagina di avanzamento.

---

## 7. Passo 4 — Elaborazione e riepilogo

### Avanzamento

La pagina di avanzamento mostra una barra con il numero di righe elaborate su quelle totali. Se l'elaborazione appare bloccata, il sistema avvisa dopo circa 30 secondi; in tal caso si può tornare alla lista articoli e ricontrollare lo **storico importazioni**.

### Riepilogo

A elaborazione conclusa viene mostrata la pagina di riepilogo con:

- Righe **processate**.
- Articoli **creati**.
- Articoli **aggiornati**.
- **Errori** (righe scartate), con il dettaglio per riga del motivo.

Da qui è possibile:

- **Scaricare le righe in errore** (file `righe_errore_import.xlsx` con riga, gencode, errore e valori della riga) per correggerle e reimportarle.
- Tornare alla **lista articoli**.
- Aprire il **dettaglio** della log di importazione o lo **storico importazioni**.
- Eseguire il **Rollback** dell'importazione (vedi sotto).

---

## 8. Annullamento, rollback e storico

- **Annulla** (prima della conferma): scarta l'anteprima caricata senza toccare alcun dato. Se l'importazione era già partita, la marca come **cancellata** nello storico.
- **Rollback** (dopo l'importazione): elimina **solo gli articoli creati** in questa importazione. Gli articoli che erano già presenti e sono stati **aggiornati non vengono ripristinati**: il riepilogo di conferma avvisa di questo limite.
- **Storico importazioni**: dalla sezione Articoli si accede alla lista delle importazioni eseguite, ognuna con stato (completata, annullata, fallita, in elaborazione, rollback), file, righe e conteggi.

---

## 9. Consigli e casi particolari

- **Sovrascrittura silenziosa**: prima di confermare, controllate il conteggio "Articoli aggiornati" nel riepilogo. Se non volete modificare articoli esistenti, verificate che i gencodici del file siano nuovi.
- **Collezioni nuove**: vengono create solo alla conferma; in anteprima appaiono in verde con l'etichetta "Nuova".
- **Prezzi**: usate il punto o la virgola come separatore decimale; evitate valori negativi o testi non numerici, che fanno scartare la riga.
- **Duplicati nel file**: due righe con gli stessi codici e la stessa collezione bloccano la conferma (gencode duplicato); correggete o eliminate le righe duplicate in anteprima.
- **Colonna `dove`**: al momento il valore viene letto ma **non** applicato all'articolo; trattatela come informazione di supporto.
- **Timeout**: i dati dell'anteprima restano disponibili per **30 minuti**; oltre questo tempo è necessario ricaricare il file.

---

*Flusso tecnico di riferimento: `context/flows/articles_flow.md`.*