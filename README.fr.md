# SalaryTicker

<!-- language-bar -->
[English](README.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · **Français** · [Deutsch](README.de.md) · [Português](README.pt.md) · [Bahasa Melayu](README.ms.md)
<!-- language-bar -->

Ce que vous avez gagné jusqu'ici aujourd'hui, seconde par seconde — dans la barre des menus du Mac, sur l'iPhone, sur l'Apple Watch et sur la Dynamic Island.

<img src="docs/panel.png" width="360" alt="Le panneau : les gains du jour, les taux qui les produisent, le total de ce mois-ci, et deux objectifs d'épargne avec les dates auxquelles ils seront payés.">

Elle se loge dans la barre des menus sous la forme d'un montant et d'un petit anneau de progression. Cliquez dessus pour le détail de la journée, le mois en cours et votre avancée vers ce pour quoi vous économisez.

- **Défile à la seconde** selon vos vrais horaires — heures, pause déjeuner non payée, jours ouvrés.
- **Sait ce qu'est un congé.** Jours fériés, congés payés et congés non payés ne tombent pas au même endroit, et un congé non payé n'entame que votre salaire de base, pas vos indemnités.
- **Convertit les prix en travail.** Un objectif s'affiche en jours de travail, avec la date à laquelle vos horaires disent qu'il sera payé, pas seulement en argent.
- **Neuf langues**, n'importe quel symbole monétaire, n'importe quel fuseau horaire IANA.
- **Aucun compte, aucun réseau, aucune télémétrie.** Tout est calculé sur votre propre appareil à partir des réglages que vous avez saisis.
- **Quatre écrans, un seul calcul.** Le Mac, le téléphone, la montre et la Dynamic Island lisent tous le même code métier, ils ne peuvent donc pas être en désaccord sur ce que vaut une seconde.

## Installation

### L'app pour Mac

Nécessite **macOS 26 ou une version ultérieure** et une chaîne d'outils Swift 6. Compilée et testée avec Swift 6.3 ; les versions antérieures de Swift 6 n'ont pas été testées.

```bash
git clone https://github.com/EnRui11/SalaryTicker.git
cd SalaryTicker
make install
```

Cela compile un binaire en release, génère l'icône de l'app depuis les sources, assemble `SalaryTicker.app`, le signe en ad-hoc, le copie dans `/Applications` et le lance. `make app` fait la même chose sans l'installer.

Il n'y a rien à sortir de la quarantaine : vous avez compilé le binaire vous-même, il ne porte donc jamais l'attribut de téléchargement que Gatekeeper surveille. La signature est ad-hoc, ce qui suffit pour une app compilée localement et donne à l'élément d'ouverture de session une identité stable.

Pour mettre à jour, faites un pull et relancez la même commande — elle remplace la copie installée et redémarre l'app. Vos réglages vivent en dehors du bundle et ne sont pas touchés.

Pour désinstaller : quittez l'app depuis le panneau, supprimez `/Applications/SalaryTicker.app`, et si vous voulez aussi effacer les réglages, `defaults delete com.steve.salaryticker`.

### L'iPhone et l'Apple Watch

Nécessite **iOS 26 / watchOS 26**, Xcode 26 et [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
make run      # the phone, on the iOS Simulator
make watch    # the watch, on the paired watch simulator
```

Simulateurs uniquement en l'état : toutes les cibles sont compilées sans signature de code. Poser cela sur du vrai matériel suppose d'abord d'ajouter un identifiant Apple dans Xcode, et le profil de provisionnement d'un compte gratuit expire au bout de sept jours — après quoi l'app ne s'ouvre plus tant que vous ne l'avez pas recompilée.

Sur un vrai iPhone, l'app de la montre ne s'installe pas séparément. Elle est livrée **à l'intérieur** de l'app du téléphone : vous installez donc l'app du téléphone, puis vous laissez l'installation automatique des apps activée, ou bien vous ouvrez l'app **Watch** de l'iPhone et touchez Installer à côté de SalaryTicker sous les apps disponibles. Les simulateurs n'ont rien de cette mécanique, et c'est pourquoi `make watch` la pose directement sur la montre.

## Premier lancement

La barre des menus affiche `Définir le salaire` tant que les horaires ne tiennent pas debout. Ouvrez **Réglages** depuis le panneau et remplissez trois choses :

1. **Onglet Salaire** — votre salaire de base, et les éventuelles indemnités fixes à côté.
2. **Onglet Horaires** — l'arrivée, le départ et la pause déjeuner non payée.
3. **Onglet Salaire, Jours ouvrés** — quels jours de la semaine vous travaillez, et lesquels sont des demi-journées.

<img src="docs/settings.png" width="420" alt="L'onglet Salaire : salaire de base, indemnités, nombre de jours ouvrés du mois, taux horaire déduit, et la grille du mois pour marquer les congés.">

Cela suffit pour démarrer. Tout le reste est facultatif.

## La configuration

### Salaire de base et indemnités

Deux champs, parce qu'une fiche de paie compte au moins deux lignes et que les congés ne les traitent pas de la même façon :

- Le **salaire de base** est la part dont un congé non payé est déduit.
- Les **indemnités** sont une somme mensuelle fixe — transport, téléphone — versée intégralement, que vous ayez pris un congé sans solde ou non.

Si vous n'avez pas d'indemnités, laissez le champ à zéro et rien ne change. Si vous en avez, les séparer correctement est ce qui empêche une journée de congé non payé de coûter plus qu'elle ne coûte vraiment.

### Jours ouvrés, jours fériés et congés

Choisissez vos jours de la semaine, et marquez n'importe lequel comme **demi-journée** (un samedi matin, par exemple) — il compte pour moitié partout.

Cliquez sur une date de la grille du mois pour la faire tourner : **travaillé → congé payé → non payé → travaillé**. Les flèches de part et d'autre du titre font défiler les mois, et le titre lui-même est le chemin du retour vers aujourd'hui, si bien que vous pouvez saisir les jours fériés de l'année prochaine avant qu'ils n'arrivent.

Les deux types de congé ne tombent pas au même endroit, et c'est toute la différence :

|                     | Ce que cela fait                                                                                                                                                                                                  |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Congé **payé**      | Ne vous coûte rien. Le même salaire couvre désormais moins de jours ouvrés, donc chaque jour que vous travaillez *vraiment* vaut un peu plus. Rien ne défile le jour du congé lui-même — sa part est portée par les autres jours. |
| Congé **non payé**  | Coûte une journée de salaire **de base**. Vos indemnités arrivent quand même intégralement.                                                                                                                        |

Une conséquence à connaître : marquer comme congé payé un jour **déjà passé** fait baisser le total de ce mois-ci, parce que la part de ce jour doit maintenant être gagnée sur les jours qui restent. À la fin du mois, le total retombe sur votre salaire.

### Heures supplémentaires

Désactivées par défaut. Une fois activées, le compteur continue après le départ, avec le coefficient que vous fixez.

Elles sont **plafonnées** — quatre heures par défaut, et jamais au-delà de minuit — parce que l'app ignore l'heure à laquelle vous êtes réellement parti. Sans plafond, un Mac laissé allumé toute la nuit inventerait une soirée entière de salaire.

### Objectifs

Ajoutez ce pour quoi vous économisez. Chacun indique ce qu'il coûte en **jours de travail** et la date à laquelle vos horaires disent qu'il sera payé. Affichez dans le panneau ceux que vous voulez y voir ; les autres restent dans les Réglages.

**Réordonnez-les avec les flèches situées à côté de chacun, ou par glisser-déposer.** Un ringgit ne peut être dépensé qu'une fois : les objectifs sont donc financés du haut de la liste vers le bas. Un objectif ne commence à se remplir qu'une fois ceux du dessus payés, et sa date intègre cette attente. L'argent déjà acquis à un objectif y reste — placer un nouvel objectif en tête ne reprend rien à un plus ancien déjà servi.

La date **ne bouge pas tant que vous travaillez.** Ce que vous gagnez et ce que fait l'horloge avancent ensemble : suivre vos horaires tient la promesse au lieu de la repousser. La seule chose qui la décale, c'est de changer les horaires en dessous — marquer un congé, retirer un jour ouvré, raccourcir la journée.

### La barre des menus

| Option                        | Ce que cela fait                                                                            |
| ----------------------------- | -------------------------------------------------------------------------------------------- |
| Anneau de progression         | Un petit anneau à côté du montant, qui se remplit au fil de la journée                      |
| Symbole monétaire             | L'afficher ou le masquer, pour récupérer un caractère de largeur                            |
| Icône seule hors des horaires | Réduit l'élément quand le montant ne bouge pas — le soir, le week-end, avant l'arrivée      |
| **Masquer le montant**        | Retire l'argent de la barre des menus jusqu'à ce que vous le redemandiez, quelle que soit l'heure |

**Masquer le montant** est aussi le premier élément du panneau, à un clic de la barre des menus, pour les moments où un appel démarre ou où quelqu'un lit par-dessus votre épaule. Cela ne masque jamais *tout* — l'anneau reste, sinon il ne resterait rien sur quoi cliquer pour faire revenir le montant.

### Lancer à l'ouverture de session

Nécessite que l'app soit lancée depuis `/Applications`. Ce qui est stocké, c'est ce que vous avez demandé : l'app s'inscrit au démarrage quand l'option est activée, et ne se désinscrit jamais, parce que macOS range les apps de la barre des menus parmi les éléments d'ouverture de session du simple fait qu'elles ont tourné une fois, et que sa réponse n'est fiable dans aucun des deux sens.

## Sur le téléphone et la montre

Les quatre mêmes montants que ceux du panneau, dans le même ordre, parce que quelqu'un qui utilise les deux ne devrait pas avoir à apprendre l'app deux fois.

<img src="docs/phone.png" width="300" alt="Le téléphone : les gains du jour, les taux qui les produisent, le total de ce mois-ci, et un objectif avec la date à laquelle il sera payé."> <img src="docs/watch.png" width="300" alt="La montre : les gains du jour, le temps restant avant le départ, le total de ce mois-ci, et le premier objectif épinglé.">

### Faire passer vos réglages

Ouvrez **Réglages → Système → Envoyer au téléphone** sur le Mac et pointez l'appareil photo du téléphone vers le QR code. Tout voyage — salaire, horaires, jours ouvrés, congés, objectifs — si bien que le téléphone démarre sur vos chiffres plutôt que sur les valeurs par défaut.

En dessous, le code encode un lien. C'est ce qui rend l'import testable, tout simplement : un simulateur n'a pas d'appareil photo, mais on peut lui passer une URL.

Il contient votre salaire, et c'est pour cela que c'est une image et non une chaîne de caractères que vous pouvez copier. Un code affiché à l'écran passe dans un appareil photo et nulle part ailleurs ; dès l'instant où il deviendrait du texte dans une feuille de partage, il aurait une chance de finir quelque part où il n'aurait jamais dû être.

### Le téléphone

Un seul écran qui défile plutôt que les onglets du Mac, parce qu'un téléphone défile de toute façon et que des onglets cacheraient ce que vous êtes venu changer derrière une devinette sur l'onglet où cela se trouve.

**Les objectifs s'ajoutent ici**, depuis l'écran principal, et la feuille demande le nom et le prix avant de créer quoi que ce soit. C'est dans les Réglages que vous les renommez, changez leur prix, les réordonnez et les supprimez.

### La montre

L'app de la montre ne garde aucun réglage à elle et ne vous donne aucun moyen de les saisir — une montre ne peut pas scanner un QR code. Elle attend le téléphone, qui envoie les réglages les plus récents à chaque changement. L'app du téléphone doit donc avoir été ouverte au moins une fois, sinon la montre n'a rien à afficher. Il y a aussi une complication pour le cadran de la montre.

### La Dynamic Island et l'écran verrouillé

S'active dans **Réglages → Affichage → Dynamic Island**, et s'y désactive quand vous préférez ne pas avoir votre paie sur l'écran verrouillé. iOS a son propre interrupteur pour les activités en direct ; celui-ci ne peut jamais qu'en retrancher.

Ce qui bouge là-bas bouge sans qu'aucun code ne tourne. iOS anime le compte à rebours jusqu'au départ et la barre de progression sur une plage de dates fixée à l'avance, si bien que les deux restent vivants et exacts des heures après la dernière ouverture de l'app.

**L'argent, lui, ne bouge pas**, et ne prétend pas le faire. Le rafraîchir demanderait l'app au premier plan ou un serveur de push, et il n'y a ni l'un ni l'autre — il est donc affiché comme un montant avec, à côté, l'heure à laquelle il a été relevé. Un compteur qui s'est arrêté en silence est pire qu'un compteur qui dit quand il s'est arrêté.

Touchez l'île de façon prolongée pour la vue étendue. Un **appui ouvre l'app** : iOS réserve l'appui à cela et n'offre aucun moyen de demander autre chose.

## Comment le montant est calculé

```
basic per day     = basic salary ÷ (scheduled days − paid leave)
allowance per day = allowance    ÷ (scheduled days − all leave)
per second        = (basic per day + allowance per day) ÷ paid seconds per day
today             = paid seconds elapsed today × per second
this month        = days already earned × daily pay + today
```

Les deux diviseurs sont comptés sur le **vrai mois calendaire**, si bien qu'un mois entièrement travaillé fait exactement votre salaire et que le taux journalier bouge un peu d'un mois à l'autre — août 2026 compte 21 jours ouvrés, septembre 22, février 2027 en compte 20.

Les heures payées par jour découlent de l'arrivée, du départ et de la pause déjeuner. Il n'y a pas de champ « heures par jour » distinct, les deux ne peuvent donc jamais se contredire.

### Il ne peut pas dériver

Chaque rafraîchissement recalcule à partir de `(settings, now)` et **n'accumule rien**. Rabattre l'écran, mettre le Mac en veille, quitter et relancer, changer l'horloge du système, traverser des fuseaux horaires en avion — rien de tout cela ne peut fausser le montant, parce qu'il n'y a aucun total cumulé à fausser.

Le minuteur dit seulement « il est temps de redessiner ». Il ne compte pas, et il ralentit jusqu'à une sieste de 20 secondes dès que le montant est figé, c'est-à-dire la plupart des soirs et tous les week-ends.

### Il n'y a pas de bouton pause, et c'est délibéré

Le calcul sature aux deux bouts de la plage payée : un instant avant la journée de travail vaut zéro, un instant après vaut une journée complète. Le montant **s'arrête donc tout seul après le départ et se remet à zéro tout seul à minuit** — aucun minuteur à arrêter, aucun état à réinitialiser.

Une pause manuelle a brièvement existé. C'était le seul état accumulé de l'app et la source de ses deux pires bugs : une pause laissée courir toute la nuit facturait plus qu'une journée de travail entière et mettait la suivante à zéro, et une pause démarrée après le départ faisait défiler le total du jour, pourtant arrêté, *à l'envers*. Supprimer la fonction a supprimé toute la classe de bugs.

## Limites connues

- **Pas de poste de nuit.** Le départ doit être plus tard que l'arrivée ; sinon l'app affiche « Configuration incomplète » au lieu d'un montant faux.
- **Pas de prime.** Seule une indemnité mensuelle fixe est modélisée. Un versement occasionnel ou de fin d'année devrait être amorti en un montant par seconde pour apparaître ici, et cela flatte le montant au lieu de le décrire.
- **Ni impôt, ni EPF, ni SOCSO.** Tous les chiffres sont bruts.
- **Pas d'historique.** Le total de ce mois-ci est déduit des horaires du mois en cours, pas d'un relevé de ce qui a réellement été travaillé. Modifier votre salaire ou vos horaires recalcule la valeur des jours déjà passés du mois en cours.
- **Un seul horaire.** Un rythme qui n'est pas hebdomadaire — un samedi sur deux, une rotation d'équipes — ne peut s'exprimer qu'en marquant les exceptions à la main.
- **Simulateurs uniquement sur iOS.** Rien ici n'est signé pour du vrai matériel, et le profil d'un compte Apple gratuit ne dure que sept jours : un téléphone et une montre que vous portez vraiment devraient donc être redéployés chaque semaine.

## Développement

```bash
make                 # list every target
make test            # 276 tests
make install         # the Mac app, into /Applications
make run             # the iPhone app, on the simulator
make watch           # the watch app, on the paired watch simulator
```

Clean Architecture orientée fonctionnalités, une cible SwiftPM par couche, de sorte que le sens des dépendances est imposé par le compilateur plutôt que par la discipline. Les décisions de conception, les invariants du modèle monétaire et les bugs qui les ont façonnés sont détaillés dans [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Licence

MIT — voir [LICENSE](LICENSE).
