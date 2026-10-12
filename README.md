# Perudo

Le jeu de dés menteur, en Flutter : contre des bots ou en ligne entre amis.

Jouer : <https://thomsgodart.github.io/perudo/>

- **Règles** : celles de <https://fr.wikipedia.org/wiki/Perudo> — pacos jokers, passage aux pacos (moitié arrondie au-dessus) et retour (double plus un), Dudo, Calza (option), Palifico. Elles sont dans `lib/engine/` (Dart pur) et résumées dans l'écran « Règles ».
- **Contre des bots** : 1 à 5 bots, trois niveaux (`lib/bots/bot.dart`).
- **En ligne** : un salon à code de quatre lettres. Le téléphone de l'hôte fait tourner la partie et envoie à chaque invité ce que son siège a le droit de voir.

## Lancer

```sh
flutter run
flutter test
```

## Architecture

| Morceau | Où | Hébergement |
|---|---|---|
| L'appli (web) | `lib/`, `web/` | GitHub Pages, publiée par `.github/workflows/pages.yml` à chaque push sur `main` |
| Les salons en ligne | `cloudflare/` | Un Worker Cloudflare et un Durable Object par salon |

Il n'y a pas de base de données : le Worker ne fait que relayer, par WebSocket, ce que les téléphones d'un salon se disent. Rien n'est stocké, et un salon vide ne coûte rien (les WebSockets hibernent). Le tout tient dans l'offre gratuite de Cloudflare.

Le protocole : chaque téléphone ouvre `wss://…/room/CODE?id=SON_ID` et envoie `{"to": "id ou null", "body": {…}}` ; le Worker transmet `{"from": "id", "body": {…}}` au destinataire, ou à tous les autres. Un message peut se perdre : c'est `lib/online/online_room.dart` qui rattrape (battement de cœur, renvoi de l'état).

## Les salons en ligne (Cloudflare)

```sh
cd cloudflare
npx wrangler login     # une seule fois
npx wrangler deploy    # https://perudo-rooms.thomsgodart.workers.dev
```

Les pages web autorisées à ouvrir un salon sont listées dans `ALLOWED_ORIGINS` (`cloudflare/wrangler.jsonc`) ; `localhost` et les applis natives passent toujours.

Pour essayer en local :

```sh
cd cloudflare && npx wrangler dev                      # http://localhost:8787
flutter run -d chrome --dart-define=ROOMS_URL=http://localhost:8787
```

Sans `--dart-define`, l'appli parle au Worker déployé : son adresse est écrite dans `lib/online/online_backend.dart`. Elle n'est pas un secret, elle est de toute façon dans le JavaScript servi.

## Publier le site (GitHub Pages)

1. Dans le dépôt GitHub : **Settings → Pages → Source : GitHub Actions**.
2. Pousser sur `main` : le workflow analyse, teste, construit avec `--base-href /perudo/` et publie.

## Organisation

| Dossier | Rôle |
|---|---|
| `lib/engine/` | Règles : annonces légales, Dudo, Calza, Palifico, ce qu'un siège voit (`GameView`). |
| `lib/bots/` | Bots probabilistes. |
| `lib/game/` | La table : `GameTable` (moteur + bots + pauses), l'écran, le gobelet, le panneau d'annonce. |
| `lib/online/` | Salon, hôte, invité, discussion et réactions ; `cloudflare_room_transport.dart` parle au Worker. |
| `lib/settings/` | Profil (nom, couleur des dés) et préférences. |
| `cloudflare/` | Le Worker qui relaie les salons. |
