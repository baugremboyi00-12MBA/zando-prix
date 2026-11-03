# Zando Prix

Site libre et gratuit pour suivre le prix des denrées alimentaires en république du Congo, par département, ville et marché. Aucun compte n'est demandé aux visiteurs.

- **Relevés de terrain :** toute personne peut signaler un prix, même hors connexion. Le relevé part au retour du réseau.
- **Estimations en ligne :** les prix de la Banque mondiale sont importés automatiquement. Ils couvrent 13 marchés dans 7 départements et 4 produits, et restent affichés à part des relevés.
- **Panier :** il estime le budget des courses et compare son coût entre les départements.
- **Favoris et partage :** chacun garde ses produits suivis sur son téléphone et peut partager un prix ou un panier, par exemple sur WhatsApp.
- **Tendances :** les plus fortes hausses et baisses relevées sur 30 jours sont affichées.
- **Installation sur téléphone :** le site peut être ajouté à l'écran d'accueil depuis le navigateur.

## Mise en ligne (environ 20 minutes, sans rien installer)

### 1. Créer la base de données (Supabase)

1. Crée un compte gratuit sur [supabase.com](https://supabase.com), puis un nouveau projet.
2. Ouvre **SQL Editor**, colle tout le contenu de `supabase/schema.sql`, puis clique sur **Run**.
3. Ouvre les réglages du projet, section **API** ou **API Keys**, et note l'**URL du projet** et la clé publique (**publishable** ou **anon**).
4. Ouvre `config.js` dans le Bloc-notes et remplis `supabaseUrl` et `supabaseKey`.

Ne mets jamais la clé **secret** ou **service_role** dans `config.js` : ce fichier est public.

### 2. Publier le site (GitHub)

1. Crée un compte gratuit sur [github.com](https://github.com), puis un dépôt **public** nommé `zando-prix`.
2. Clique sur **uploading an existing file**, glisse tout le contenu du dossier `zando-prix-web`, puis valide avec **Commit changes**.
3. Vérifie que le fichier `.github/workflows/mise-a-jour.yml` est bien présent. S'il manque, clique sur **Add file > Create new file**, saisis exactement ce chemin comme nom et colle le contenu du fichier.
4. Ouvre **Settings > Pages** et, sous **Source**, choisis **GitHub Actions**.
5. Ouvre l'onglet **Actions**, sélectionne **Mise à jour et publication**, puis clique sur **Run workflow**.

Le site est ensuite en ligne à l'adresse `https://TON-NOM.github.io/zando-prix/`. Il suffit de partager ce lien.

## Fonctionnement au quotidien

- **Mise à jour :** GitHub vérifie les nouveaux prix le lundi et le jeudi, publie le site et garde la base Supabase active. Ton PC peut rester éteint.
- **Suppression d'un faux relevé :** ouvre Supabase, **Table Editor**, table `releves`, sélectionne la ligne puis supprime-la. Chaque contributeur peut aussi annuler sa propre saisie pendant 24 heures depuis son téléphone.
- **Protection contre les abus :** la base limite les envois à 40 relevés par heure et par connexion et refuse les prix hors limites. Cela ne garantit pas qu'un prix soit exact : contrôle les relevés régulièrement.

## Limites des services gratuits

- **Supabase :** un projet gratuit se met en pause après une semaine sans activité. Le passage automatique du lundi et du jeudi sert à l'éviter. S'il est quand même en pause, relance-le depuis le tableau de bord.
- **GitHub :** les tâches programmées s'arrêtent après 60 jours sans activité dans le dépôt. Les mises à jour mensuelles des prix suffisent normalement. Sinon, réactive-les dans l'onglet **Actions**.

## Source des estimations

Andrée, B. P. J. (2021), *Monthly food price estimates by product and market*, Banque mondiale, https://doi.org/10.48529/2ZH0-JF55. Ce sont des prix calculés par un modèle, à vérifier sur place.

## Licence

Code sous licence MIT (voir `LICENSE`). L'attribution de la source des données doit être conservée.
