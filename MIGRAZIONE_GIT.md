# Migrazione repo su Gitea — reporting-serchiolog

## Problema: HTTP 413 al push

Il push su Gitea falliva con:

```
error: RPC failed; HTTP 413 curl 22 The requested URL returned error: 413
```

Il repo passava attraverso un tunnel **Cloudflare** (piano free) che ha un limite di ~100 MB per upload.
Il repo pesava ~108 MB a causa di **1173 file `.xps`** presenti nella history di git (già cancellati dal working tree ma ancora negli oggetti git).

---

## Causa

Git non cancella mai fisicamente i file dalla history. Anche se rimossi con `git rm` in un commit passato, i file restano negli oggetti `.git/objects` e contribuiscono al peso del repo.

Per verificare i file "nascosti" nella history:

```bash
git lfs migrate info --top=10
```

---

## Soluzione: git-filter-repo

### Installazione (Windows, Python 3.12, senza permessi admin)

```bash
python -m pip install --user git-filter-repo
```

Il tool viene installato in:
`C:\Users\<utente>\AppData\Roaming\Python\Python312\Scripts\`

### Rimozione dei file dalla history

```bash
python -m git_filter_repo --invert-paths --path-glob "*.xps" --path-glob "*.xpS" --force
```

> **Nota:** `--force` è necessario perché il repo non è un clone fresco.
> Dopo l'operazione, `git-filter-repo` rimuove automaticamente il remote `origin`.

### Ripristino dei remote e push

```bash
git remote add origin https://git.deelab.org/DCTO/reporting-serchiolog.git
git remote set-url --add origin https://github.com/rivaldid/reporting-serchiolog.git
git push --force -u origin master
```

---

## Configurazione multi-remote (push simultaneo su Gitea + GitHub)

Nel file `.git/config`:

```ini
[remote "origin"]
    url = https://git.deelab.org/DCTO/reporting-serchiolog.git
    url = https://github.com/rivaldid/reporting-serchiolog.git
    fetch = +refs/heads/*:refs/remotes/origin/*
[branch "master"]
    remote = origin
    merge = refs/heads/master
```

Con questa configurazione `git push` manda su entrambi i remote simultaneamente.
