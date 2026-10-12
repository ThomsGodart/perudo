import '../bots/bot.dart';
import '../settings/app_settings.dart';

/// Everything the player reads, in French.
abstract final class Strings {
  static const appTitle = 'Perudo';
  static const tagline = 'Le jeu de dés menteur';

  static const cancel = 'Annuler';
  static const save = 'Enregistrer';
  static const close = 'Fermer';
  static const quit = 'Quitter';
  static const stay = 'Rester';

  // Home
  static const playSolo = 'Jouer contre des bots';
  static const playOnline = 'Jouer en ligne';
  static const rules = 'Règles';
  static const settings = 'Préférences';
  static const profile = 'Profil';

  // Profile
  static const profileTitle = 'Ton profil';
  static const playerNameLabel = 'Ton nom';
  static const diceColorLabel = 'Couleur de tes dés';
  static const diceColorNote =
      'Si quelqu\'un a déjà cette couleur dans une partie en ligne, une '
      'autre te sera donnée : tu pourras la changer dans le salon.';
  static const nameRequired = 'Choisis un nom (autre que « Toi »).';

  // Solo setup
  static const soloTitle = 'Partie contre des bots';
  static const botCount = 'Nombre de bots';
  static const botLevelLabel = 'Niveau des bots';
  static String botLevel(BotLevel level) => switch (level) {
    BotLevel.easy => 'Facile',
    BotLevel.normal => 'Normal',
    BotLevel.hard => 'Difficile',
  };
  static const diceCount = 'Dés par joueur';
  static const diceCountNote = 'Moins de dés : une partie plus rapide.';
  static const calzaOption = 'Jouer avec le Calza';
  static const calzaOptionNote =
      'Annoncer que la mise est exacte : un dé regagné si c\'est vrai, un dé '
      'perdu sinon.';
  static const start = 'Lancer la partie';

  // Settings
  static const settingsTable = 'Table';
  static const settingsGame = 'Jeu';
  static const showDiceTally = 'Compte des dés au centre';
  static const showDiceTallyNote =
      'Affiche le nombre de dés en jeu et de dés éliminés.';
  static const showOpponentDice = 'Dés restants des adversaires';
  static const showOpponentDiceNote =
      'Affiche à côté de chaque joueur combien de dés il lui reste.';
  static const cupAlwaysUp = 'Garder mon gobelet levé';
  static const cupAlwaysUpNote =
      'Tes dés restent visibles. Sinon, touche le gobelet pour les revoir.';
  static const reduceMotion = 'Réduire les animations';
  static const botSpeedLabel = 'Vitesse des bots';
  static String botSpeed(BotSpeed speed) => switch (speed) {
    BotSpeed.slow => 'Lente',
    BotSpeed.normal => 'Normale',
    BotSpeed.fast => 'Rapide',
  };

  // Table
  static String round(int round) => 'Manche $round';
  static const palificoTitle = 'PALIFICO';
  static const palificoBody =
      'Les pacos ne sont pas des jokers · la valeur annoncée ne change pas';
  static const paco = 'paco';
  static const pacos = 'pacos';
  static String faceName(int face, {bool plural = false}) =>
      face == 1 ? (plural ? pacos : paco) : '$face';
  static const yourTurn = 'À toi de parler';
  static String turnOf(String name) => 'Au tour de $name…';
  static const openingHint = 'Tu ouvres la manche : fais la première annonce.';
  static const bid = 'Annoncer';
  static const dudo = 'Dudo !';
  static const calza = 'Calza';
  static const dudoHint = 'Je doute';
  static const calzaHint = 'Exactement';
  static const noBidYet = 'Aucune annonce';
  static String bidBy(String name) => 'annoncé par $name';
  static String diceInPlay(int count) =>
      '$count dé${count > 1 ? 's' : ''} en jeu';
  static String diceLost(int count) => '$count éliminé${count > 1 ? 's' : ''}';
  static const tapCup = 'Touche le gobelet pour voir tes dés';
  static const tapCupHide = 'Touche le gobelet pour cacher tes dés';
  static const youAreOut = 'Tu n\'as plus de dés : tu regardes la fin.';
  static const out = 'éliminé';
  static const you = 'toi';
  static const history = 'Annonces de la manche';
  static const historyEmpty = 'Personne n\'a encore parlé.';
  static const pacosNotWild = 'Pacos non jokers';

  static String dudoCalled(String caller, String bidder) =>
      '$caller doute de $bidder';
  static String calzaCalled(String caller) => '$caller annonce Calza';
  static String actualCount(int count) => 'Il y en a $count';
  static const pacosIncluded = 'pacos compris';
  static String losesDie(String name) => '$name perd un dé';
  static String gainsDie(String name) => '$name regagne un dé';
  static String keepsDice(String name) => '$name a déjà tous ses dés';
  static String eliminated(String name) => '$name est éliminé';
  static const next = 'Continuer';
  static const waitingOthers = 'En attente des autres joueurs…';
  static String wins(String name) => '$name gagne la partie !';
  static const youWin = 'Tu gagnes la partie !';
  static const playAgain = 'Rejouer';
  static const waitingRematch = 'L\'hôte peut relancer une partie.';
  static const leaveTitle = 'Quitter la partie ?';
  static const leaveSolo = 'La partie en cours sera perdue.';
  static const leaveHost = 'Tu es l\'hôte : la partie s\'arrêtera pour tous.';
  static const leaveGuest = 'Un bot jouera à ta place.';

  // Chat
  static const chatTitle = 'Discussion';
  static const chatEmpty = 'Aucun message pour l\'instant.';
  static const chatHint = 'Écrire un message…';
  static const chatSend = 'Envoyer';
  static const reactions = 'Réagir';

  // Online
  static const onlineIntro =
      'Crée une partie et donne son code à tes amis, ou rejoins la leur.';
  static const onlineCreate = 'Créer une partie';
  static const onlineJoin = 'Rejoindre';
  static const onlineCodeLabel = 'Code de la partie';
  static const onlineCodeHint = 'ABCD';
  static const onlineRoomTitle = 'Salon';
  static const onlineShareCode = 'Donne ce code aux autres joueurs.';
  static const onlineCodeCopied = 'Code copié';
  static const onlineWaitingHost = 'En attente que l\'hôte lance la partie…';
  static const onlineConnecting = 'Connexion…';
  static const onlineNeedPlayers =
      'Il faut au moins deux joueurs : attends un ami ou ajoute un bot.';
  static const onlineBots = 'Bots';
  static const onlinePickColor = 'Tes dés';
  static const onlineHostTag = 'hôte';
  static const onlineAwayTag = 'absent';
  static const onlineHostAway =
      'L\'hôte ne répond plus : la partie reprendra à son retour.';
  static const onlineClosed = 'L\'hôte a mis fin à la partie.';
  static String onlineRefused(String reason) => switch (reason) {
    'full' => 'Cette partie est complète.',
    'started' => 'Cette partie a déjà commencé.',
    'version' =>
      'Cette partie utilise une autre version de l\'application : '
          'mettez-la à jour.',
    'network' => 'Connexion impossible. Vérifie ta connexion internet.',
    _ => 'Aucune partie trouvée avec ce code.',
  };
  static const onlineNotConfigured =
      'Le jeu en ligne n\'est pas encore configuré dans cette version.';

  // Rules
  static const rulesSections = [
    (
      'But du jeu',
      'Chaque joueur lance cinq dés (ou moins, pour une partie rapide) sous '
          'son gobelet et ne voit que les siens. À tour de rôle, on annonce combien de dés d\'une valeur il y '
          'a au total sous tous les gobelets. Le dernier joueur à qui il reste '
          'des dés gagne.',
    ),
    (
      'Les pacos',
      'Le 1 s\'appelle le paco : c\'est un joker qui compte pour toutes les '
          'valeurs. « Cinq 6 » est donc vrai s\'il y a au moins cinq dés qui '
          'montrent 6 ou paco.',
    ),
    (
      'Annoncer',
      'Le premier joueur annonce un nombre de dés et une valeur (pas de '
          'pacos pour ouvrir). Le joueur suivant doit surenchérir : plus de '
          'dés, de n\'importe quelle valeur, ou autant de dés d\'une valeur '
          'plus haute.',
    ),
    (
      'Passer aux pacos',
      'Les pacos sont plus rares : pour passer aux pacos, on divise le '
          'nombre par deux, arrondi au-dessus (sept 5 → quatre pacos). Pour '
          'revenir à une autre valeur, on double et on ajoute un (quatre pacos '
          '→ neuf dés).',
    ),
    (
      'Dudo',
      'Au lieu de surenchérir, on peut dire « Dudo » (je doute). Tous les '
          'gobelets sont levés. Si l\'annonce était juste, celui qui a douté '
          'perd un dé ; sinon c\'est celui qui a annoncé. Le perdant ouvre la '
          'manche suivante.',
    ),
    (
      'Calza (option)',
      'On peut aussi dire « Calza » : l\'annonce est exactement juste. Si '
          'c\'est vrai, on regagne un dé (jamais plus de cinq) ; sinon on en '
          'perd un. Dans les deux cas on ouvre la manche suivante. Pas de '
          'Calza à deux joueurs ni en Palifico.',
    ),
    (
      'Palifico',
      'Quand un joueur tombe à un seul dé, la manche qu\'il ouvre est '
          'spéciale : les pacos ne sont plus des jokers, il peut ouvrir sur les '
          'pacos, et la valeur annoncée ne peut plus changer : on ne peut '
          'qu\'augmenter le nombre. Chaque joueur n\'a droit qu\'à un seul '
          'Palifico, et il n\'y en a pas quand il ne reste que deux joueurs.',
    ),
  ];
}
