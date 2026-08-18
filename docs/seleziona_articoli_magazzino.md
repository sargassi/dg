# Manuale — Seleziona Articoli (Magazzino)

Guida all'uso della pagina **Magazzino → Seleziona Articoli** (percorso `/inventories/seleziona`).

Questa pagina permette di **selezionare più articoli dal catalogo** in un'unica schermata e di passare la selezione alla schermata mobile **Carico** (`App IN`), che la riceve già compilata con gli articoli e le quantità scelte.

> La pagina di selezione **non tocca lo stock**: serve solo a raccogliere gli articoli. Il carico vero e proprio (con quantità, magazzino e ubicazione) avviene nella schermata Carico successiva.

---

## 1. Prerequisiti

- Avere il permesso **Gestione Magazzino** (`manage_inventory`).
- L'accesso avviene dalla scheda **Seleziona Articoli** della dashboard Magazzino.

---

## 2. La schermata

La schermata è divisa in due zone:

- **A sinistra**: la ricerca e la tabella del catalogo.
- **A destra**: l'area tenporanea di selezione con gli articoli scelti — appare solo quando hai selezionato almeno un articolo.

### Barra di ricerca

- **Campo di testo**: cerca in **tutte le colonne** (codice, tessuto, variante, descrizione, colore, tessuto di riferimento, ecc.). La ricerca è **automatica**: non serve premere Invio, basta scrivere.
- **Menu Collezione**: filtra il catalogo per collezione. La voce predefinita **"Tutte le collezioni"** mostra tutti gli articoli.
- **Contatore**: a destra mostra il numero di articoli risultanti dalla ricerca/filtro corrente.

I risultati appaiono nella tabella senza ricaricare la pagina; se stai cercando, il testo corrispondente viene **evidenziato in giallo** nelle righe.

---

## 3. Selezionare gli articoli

1. Spunta la casella accanto a ogni articolo che vuoi caricare: la riga si **evidenzia in verde** e l'articolo compare nel **carrello** a destra.
2. Nel carrello ogni articolo mostra il **codice** e la **collezione**, con un campo **Quantità** (predefinita a 1) e un pulsante per **rimuoverlo**.
3. Puoi continuare a cercare, cambiare pagina o filtro: **la selezione resta memorizzata** e le caselle già spuntate rimangono evidenziate quando i risultati si aggiornano.
4. Usa la **paginazione** in fondo alla tabella per scorrere il catalogo; i filtri di ricerca e collezione vengono mantenuti tra una pagina e l'altra.

Per **togliere** un articolo dalla selezione: rimuovilo dal carrello (la casella nella tabella si despunta da sola) oppure togli la spunta dalla riga.

---

## 4. Passare al carico

Quando hai finito, premi il pulsante **"Vai a Carico →"** in fondo al carrello.

Il sistema salva la selezione e ti porta alla schermata mobile **Carico (IN)** con gli articoli già inseriti (codice, collezione e quantità) nei dettagli, pronti per completare l'operazione: si sceglie il **magazzino** (e l'eventuale **ubicazione**) e si conferma il carico.

> La quantità scelta nell'area selezione viene usata come quantità predefinita: puoi modificarla liberamente nella schermata di carico.

---

## 5. Note e consigli

- **Selezione temporanea**: la selezione vive nella pagina corrente; se ricarichi o chiudi la pagina la perdi. Viene salvata solo quando premi **"Vai a Carico →"**.
- **Quantità**: il campo quantità accetta solo numeri interi (almeno 1); un valore vuoto o non valido torna a 1. Non esiste un limite superiore.
- **Nessun controllo di giacenza**: in questa pagina puoi selezionare qualsiasi articolo del catalogo, anche senza scorte; la gestione delle quantità effettive avviene nella schermata di carico.
- **Filtri indipendenti**: la ricerca testuale e il filtro per collezione si sommano (i risultati soddisfano entrambi).
- Se il carrello è vuoto, il pulsante **"Vai a Carico →"** non è visibile: seleziona almeno un articolo.

---

## 6. Collegamenti

- Flusso tecnico di riferimento: `context/flows/seleziona_articoli_magazzino.md`
- Flusso inventari: `context/flows/inventories_flow.md`