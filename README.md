# SCPI CI Werkzeuge und Test-Automation
In diesem Repository befinden sich Artefakte zur Build-Automation für  das Arbeiten mit Integration-Flows für die SCPI.

## Allgemeines
### Generelle Optionen
Die ausführbaren Skripte können entweder mit einem persönlichen S-User oder einem OAuth-Client-Token (vornehmlich
für die Benutzung in einer CI) verwendet werden. Der S-User muss für die Benutzung des OData-APIs berechtigt sein.

Folgende Funktionen stehen zur Verfügung (die ersten beiden erfordern immer die Eingabe von Benutzer und Passwort,
da sie nicht im OData-API zur Verfügung stehen, sondern direkt auf der ProcessIntegration-Anwendung aufgerufen werden):
- **ls-packages** - Listet die Packages im Design-Workspace
- **ls-design** - Listet die Artefakte im Design-Workspace.
  - Parameter [package_id] Wenn eine Package-ID angegeben wird, werden nur die Artefakte dieses Packages gelistet. Ansonsten
  die aller Packages.
- **ls-runtime** - Listet die deployten Artefakte.
- **create** - Legt ein Design-Time-Artefakt an.
- **download** - Lädt das angegebene Design-Time-Artefakt herunter.
  - Parameter <artifact_id>
  - Parameter [folder] Angabe des Verzeichnisses, in das das Artefakt heruntergeladen werden soll.
- **deploy** - Deployt das Artefakt in die Runtime.


- Bei Verwendung der Parameter -o und -c können OAuth-Client-Credentials übergeben werden, die zur Erzeugung eines
  OAuth-Tokens verwendet werden.
- Die Skripte für Design-time Artefakte und Packages funktionieren leider nicht mit OAuth-Token. Bei denen muss immer
  der Benutzername und das Passwort an der Konsole eingegeben werden.
