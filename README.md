# SCPI CI Werkzeuge
In diesem Repository befinden sich Artefakte zur Build-Automation für  das Arbeiten mit Integration-Flows für die SCPI.

## Allgemeines
Die Skripte dienen der Unterstützung des Entwicklungsprozesses, wie er in
***REMOVED***/wiki/spaces/SAPC4IP/pages/959414296/IFlow-Entwicklung+Automatisiertes+f+r+Test+und+Deployment beschrieben ist.

## Deployment / Konfiguration
Für den Remote-Zugriff auf die SAP-Cloudplattform müssen OAuth-Clients existieren. Das sind

* `***REMOVED***` für menschliche Benutzer (verwendet in `src/getOAuthToken.sh`)
* `***REMOVED***` für die CI, hier erfolgt die Authentisierung über ein Secret, das über die Pipeline-Konfiguration
  übermittelt wird.

Für den Remote-Zugriff auf Bitbucket muss ebenfalls ein OAuth-Client existieren. Das ist

* `***REMOVED***` (verwendet in `src/bitbucket.sh`, der allerdings im Moment nur im Account von mir (Uwe Voigt) eingerichtet ist

## lokale Benutzung durch Entwickler 
### Installation
Das Repository wird mittels `git clone` regulär heruntergeladen. Danach wechselt man in das Verzeichnis des Repositories
und ruft in einer Bash-Shell `. ./install` auf. Dadurch wird die Umgebungsvariable `GIT_BASE_DIR` auf `~/IdeaProjects`
gesetzt und das Verzeichnis `src` des Repositories in den Pfad aufgenommen.

Somit kann das CLI-Skript `scpi` mit den im Folgenden beschriebenen Funktionen direkt aufgerufen werden. Das Skript
unterstützt Completion in einer Shell (tabtab).

### Generelle Optionen
Das CLI kann entweder mit einem persönlichen S-User oder einem OAuth-Client-Token (vornehmlich
für die Benutzung in einer CI) verwendet werden. Der S-User muss für die Benutzung des OData-APIs berechtigt sein.

* -a `<account_id>` - der technische Name des SAP-Subaccounts (SAP Cloud Platform Cockpit / Overview)
* -o `<oauth_prefix>` - der Teil der OAuth-URLs, z.B. https://oauthasservices-<oauth_prefix>.eu2.hana.ondemand.com/oauth2 (SAP Cloud Platform Cockpit / OAuth)
* -c `<client_id:secret>` - OAuth-Client-Credentials, z.B. des odata_ci-OAuth-Clients

#### Default Verzeichnis
Für jede Funktion, die ein Quell- oder Zielverzeichnis eines Artefakts erwartet gilt der Default-Wert:

* `$GIT_BASE_DIR/iflow_<artifact_id>`, falls die Umgebungsvariable `GIT_BASE_DIR` existiert
* `../iflow_<artifact_id>`, falls die Umgebungsvariable `GIT_BASE_DIR` nicht existiert

### Funktionen
Folgende Funktionen stehen zur Verfügung (die ersten beiden erfordern immer die Eingabe von Benutzer und Passwort,
da sie nicht im OData-API zur Verfügung stehen, sondern direkt auf der Process-Integration-Anwendung aufgerufen werden).
Der Aufruf erfolgt immer über `scpi <design|runtime> <function> [parameters]`

* **`design`**
    * **`packages`** - Listet die Packages im Design-Workspace
    * **`artifacts`** - Listet die Artefakte im Design-Workspace.
        * Parameter `[package_id]` Wenn eine Package-ID angegeben wird, werden nur die Artefakte dieses Packages gelistet. Ansonsten
          die aller Packages.
    * **`create`** - Legt ein Design-Time-Artefakt an.
        * Parameter `<artifact_id>` die ID des neuen Artefakts
        * Parameter `<package_id>` die ID des Packages
        * Parameter `[artifact_name]` der Name des neuen Artefakts, default ist die Artefakt-ID
        * Parameter `[folder]` das Verzeichnis, aus dem das Artefakt gelesen wird, default s. [Default Verzeichnis](#default-verzeichnis)
    * **`delete`** - Löscht ein Design-Time-Artefakt aus dem Design-Workspace.
        * Parameter `<artifact_id>` die ID des zu löschenden Artefakts
        * Parameter `[version]` die Version des zu löschenden Artefakts, default ist `active`
    * **`deploy`** - Triggert das Deployment das Design-Time-Artefakts.
        * Parameter `<artifact_id>` die ID des zu deployenden Artefakts
        * Parameter `[version]` die Version des zu deployenden Artefakts, default ist `active`
    * **`download`** - Lädt das angegebene Design-Time-Artefakt herunter.
        * -p - führt nach dem Herunterladen automatisch ein `git commit` und `git push`aus - Wenn noch kein lokales Repository in dem Verzeichnis existiert hat,
          dann wird über das Bitbucket-API ein neues Repository mit dem Namen der Artefakt-ID angelegt.
        * Parameter `<artifact_id>` die ID des herunterzuladenden Artefakts
        * Parameter `[folder]` das Verzeichnis, in das das Artefakt heruntergeladen werden soll, default s. [Default Verzeichnis](#default-verzeichnis)
        * Parameter `[version]` die Version des herunterzuladenden Artefakts, default ist `active`
* **`runtime`**
    * **`artifacts`** - Listet die deployten Artefakte.
    * **`call`** - Ruft einen Endpoint des Artefakts auf.
        * Parameter `<artifact_id>` die ID des zu deployenden Artefakts
        * Parameter `[endpoint_url]` der URL des Endpoints, der aufgerufen werden soll. Ohne Angabe wird der einzige existierende URL aufgerufen
    * **`deploy`** - Deployt das Artefakt vom lokalen Verzeichnis in die Runtime.
        * Parameter `<artifact_id>` die ID des zu deployenden Artefakts
        * Parameter `[folder]` das Verzeichnis, aus dem das zu deployende Artefakt gelesen werden soll, default s. [Default Verzeichnis](#default-verzeichnis)
    * **`errors`** - Listet die eventuell vorhandenen Deploymentfehler des Artefakts.
        * Parameter `<artifact_id>` die ID des Artefakts
    * **`undeploy`** - Löscht das Artefakt aus der Runtime.
        * Parameter `<artifact_id>` die ID des zu löschenden Artefakts

## Benutzung in einer CI
Das Repository enthält ein `Dockerfile` mit dem in der Bitbucket-Pipeline ein Basis-Image für Bitbucket-Pipelines erstellt wird.
Das Image basiert auf `Alpine`, enthält `curl` und dieses Repository in installierter Form.

Wenn ein Integration-Flow das erst Mal mit der `-p`-Option heruntergeladen wird und ein BitBucket-Repository angelegt wird, dann wird
in dieses Repository ebenfalls die Datei `bitbucket-pipelines.yml` kopiert, sowie die notwendigen Repository-Variablen

* `DOCKER_LOGIN`
* `DOCKER_PASSWORD`
* `DEPLOY_CONFIG`

angelegt.
Demzufolge kann jeder Integration-Flow, für den auf diese Art ein Repository angelegt wird unmittelbar in die Laufzeitumgebung deployt werden.

### Repositoryvariablen
Das Repository enthält eine Konfigurationsdatei, die verwendet wird, um die angelegten Repositories mit der gleichen
Konfigurationsdatei zu versehen (die Werte müssen natürlich enthalten sein):

        #!/bin/sh
        # der Variablenpräfix muss mit dem Deployment-Environment übereinstimmen
        export TEST_ACCOUNT_ID=
        export TEST_OAUTH_PREFIX=
        export TEST_CLIENT_CREDS=
        export STAGING_ACCOUNT_ID=
        export STAGING_OAUTH_PREFIX=
        export STAGING_CLIENT_CREDS=
        export PRODUCTION_ACCOUNT_ID=
        export PRODUCTION_OAUTH_PREFIX=
        export PRODUCTION_CLIENT_CREDS=

Diese Datei ist Base64-kodiert als Bitbucket-Variable `DEPLOY_CONFIG` angelegt.