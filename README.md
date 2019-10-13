# SCPI CI Werkzeuge und Test-Automation
In diesem Repository befinden sich Artefakte zur Build-Automation für  das Arbeiten mit Integration-Flows für die SCPI.

## Allgemeines
Die Skripte dienen der Unterstützung des Entwicklungsprozesses, wie er in
***REMOVED***/wiki/spaces/SAPC4IP/pages/959414296/IFlow-Entwicklung+Automatisiertes+f+r+Test+und+Deployment beschrieben ist.

### Generelle Optionen
Die ausführbaren Skripte können entweder mit einem persönlichen S-User oder einem OAuth-Client-Token (vornehmlich
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
da sie nicht im OData-API zur Verfügung stehen, sondern direkt auf der Process-Integration-Anwendung aufgerufen werden):

* **`ls-packages`** - Listet die Packages im Design-Workspace
* **`ls-design`** - Listet die Artefakte im Design-Workspace.
    * Parameter `[package_id]` Wenn eine Package-ID angegeben wird, werden nur die Artefakte dieses Packages gelistet. Ansonsten
      die aller Packages.
* **`ls-runtime`** - Listet die deployten Artefakte.
* **`create`** - Legt ein Design-Time-Artefakt an.
    * Parameter `<artifact_id>` die ID des neuen Artefakts
    * Parameter `<package_id>` die ID des Packages
    * Parameter `[artifact_name]` der Name des neuen Artefakts, default ist die Artefakt-ID
    * Parameter `[folder]` das Verzeichnis, aus dem das Artefakt gelesen wird, default s. [Default Verzeichnis](#default-verzeichnis)
* **`download`** - Lädt das angegebene Design-Time-Artefakt herunter.
    * -p - führt nach dem Herunterladen automatisch ein `git commit` und `git push`aus - Wenn noch kein lokales Repository in dem Verzeichnis existiert hat,
      dann wird über das Bitbucket-API ein neues Repository mit dem Namen der Artefakt-ID angelegt.
    * Parameter `<artifact_id>` die ID des herunterzuladenden Artefakts
    * Parameter `[folder]` das Verzeichnis, in das das Artefakt heruntergeladen werden soll, default s. [Default Verzeichnis](#default-verzeichnis)
    * Parameter `[version]` die Version des herunterzuladenden Artefakts, default ist `active`
* **`deploy`** - Deployt das Artefakt in die Runtime.
    * Parameter `<artifact_id>` die ID des zu deployenden Artefakts
    * Parameter `[folder]` das Verzeichnis, aus dem das zu deployende Artefakt gelesen werden soll, default s. [Default Verzeichnis](#default-verzeichnis)
