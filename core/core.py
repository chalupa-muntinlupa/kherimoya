from pathlib import Path
from core import exceptions
import uuid
import json
import os
from typing import Literal
import hashlib
import time
import subprocess

PROJECT_PATH = Path(__file__).parent.parent.resolve()
if PROJECT_PATH.name.lower() != "kherimoya":
    raise exceptions.KherimoyaPathNotFoundError


class KherimoyaServer:
    """
    Represents a servever in servers/, existing or nonexisting.
    """
    # --- initialization --- #

    class Actions:
        """
        Methods which require the server to exist. This only checks KherimoyaServer.exists, which means if it was nonexisting in the past you have to call KherimoyaServer.refresh
        """
        def __init__(self, server: "KherimoyaServer") -> None:
            self.server: KherimoyaServer = server

        def _checkserver(self, text: str=''):
            if not self.server.exists:
                raise exceptions.ServerDoesNotExistError(text)

        def start_server(self, method: Literal["screen", "plugin"] = "screen"):
            """
            Starts the parent KherimoyaServer.

            Args:
                Method (Literal["screen", "plugin"]): Method in which is how you start the server. Screen will start the server through the screen session, and plugin will use the plugin (which is not yet implemented)
            """
            self._checkserver("Attempted to start a server which does NOT exist")

            server = self.server

            if method == "screen":
                self._start_through_screen(server)
            elif method == "plugin":
                raise NotImplementedError('Kherimoya\'s plugin does not exist as of now.')
                #self._start_through_plugin(server)
            else:
                raise ValueError(f"Invalid stop method: {method}")
        
        def _start_through_screen(self, server):
            # TODO: Make it so that it uses similar logic to our old scripts, where we used screen -dmS "$SERVER_NAME" endstone -y -s "$SERVER_DIR_PATH" to start servers
            pass

        def _start_through_plugin(self, server):
            # TODO: When the plugin is finished, make it use the port for the server. {ip}:{port}/{name}:{id}/start_server
            pass
        
        def stop_server(self, method: Literal["screen", "plugin"] = "screen") -> None:
            """
            Stops the parent KherimoyaServer.

            Args:
                Method (Literal["screen", "plugin"]): Method in which is how you stop the server. Screen will start the server through the screen session, and plugin will use the plugin (which is not yet implemented)
            """
            self._checkserver("Attempted to stop a server which does NOT exist")

            server = self.server

            if method == "screen":
                self._stop_through_screen(server)
            elif method == "plugin":
                raise NotImplementedError('Kherimoya\'s plugin does not exist as of now.')
                #self._stop_through_plugin(server)
            else:
                raise ValueError(f"Invalid stop method: {method}")

        def _stop_through_screen(self, server):
            # TODO: Make it so that it essentially just sends the command "stop" to the server. Do this last because we can do this manually
            pass

        def _stop_through_plugin(self, server):
            # TODO: When the plugin is finished, make it use the port for the server to stop the server. {ip}:{port}/{name}:{id}/start_server
            pass

    def __init__(self, project_path: Path, name: str, server_id: str | None = None):
        self._project_path = project_path
        self._name = name

        if server_id:
            self._path = Path(project_path / "servers" / f"{name}:{server_id}").resolve()
            self._server_id = server_id
        else:
            self._path = Path(project_path / "servers" / f"{name}").resolve()
            self._server_id = None

        if self._path.is_dir() and self._path.name == name:
            self._exists = True
        else:
            self._exists = False

        if self._exists:
            self._running = False  # TODO: Load from JSON later

            try:
                self._server_index = self._get_index_from_id()
            except exceptions.ServerDoesNotExistError:
                self._server_index = None
                self._exists = False
                self._server_id = None
        else:
            self._running = False

        # Attach Actions interface
        self._actions = KherimoyaServer.Actions(self)
    
    # --- properties --- #

    # We do this so that it's a a bit harder for external things to change attributes, and making the real attributes private emphasizes that we don't want others to change them
    # Attributes like KherimoyaServer._name and KherimoyaServer._server_id are based off of the server's actual folder, and since KherimoyaServer represents that folder, we only really change them in KherimoyaServer.refresh()

    # name: str = ''
    # server_id: str | None = None
    # server_index: int | None = None
    # path: Path
    # exists: bool = False
    # running: bool = False

    @property
    def name(self) -> str:
        return self._name
    
    @property
    def server_id(self) -> str | None:
        return self._server_id
    
    @property
    def server_index(self) -> int | None:
        return self._server_index
    
    @property
    def path(self) -> Path:
        return self._path
    
    @property
    def exists(self) -> bool:
        return self._exists
    
    @property
    def running(self) -> bool:
        return self._running

    # --- methods --- #

    def _get_index_from_id(self, base_port: int = 59100, range_size: int = 1000) -> int:
        if not self._exists or not self._server_id:
            raise exceptions.ServerDoesNotExistError("Server must exist and have a valid ID to get index.")
        
        hash_value = int(hashlib.sha256(self._server_id.encode()).hexdigest(), 16)
        return base_port + (hash_value % range_size)

    def refresh(self, path: Path) -> None:
        """
        Resets server_id, name, & path. Also writes to server.json, creating the file if it does not exist

        Should be called when creating a server, changing its name, and every once in a while
        """
        # --- check ---

        if not self._exists:
            self._server_id = None
            return
        
        if not path.is_dir():
            if self._path.is_dir():
                return
            else:
                self._server_id = None

        if not path.is_dir():
            raise FileNotFoundError(
                f"Path passed into load_and_save_metadata_plus_self is not a directory: {path}"
            )

        if path.parent.name != "servers":
            raise exceptions.ServerNotInPathError(
                f"Path passed into load_and_save_metadata_plus_self is not in servers/"
            )

        # --- set name, id, & path ---

        self._path = path

        if ":" in path.name:
            self._name, self._server_id = path.name.split(":", 1)
        else:
            self._name = path.name
            self._server_id = None

        # --- write to json ---
        with open(path / "server.json", "w", encoding="utf-8") as f:
            json.dump(
                {
                    "name": self._name,
                    "id": self._server_id
                },
                f,
                indent=4
            )


class ServerManager:
    """
    Holds methods to manage servers.
    """

    # --- initialization --- #

    def __init__(self, project_path: Path, strict_names: bool = True):
        self.project_path = project_path
        self.strict_names = strict_names

    # --- methods --- #

    def list_servers(self, sole_names: bool = False, sole_ids: bool = False) -> list[tuple[str, str]] | list[str | None]:
        """
        Lists all of the servers in the servers/ directory.

        Args:
            sole_names (bool = False): Appends the name of the server rather than a tuple with the server's id as well
            sole_ids (bool = False): Appends the id of the server rather than a tuple with the server's name as well

        Returns:
            Either a list with tuples for each server (index 0 is the name, index 1 is the id)
            OR a plain list with strings of the name and/or id of each server.

        Example:
            ```
            # Get all servers as (name, id) tuples (default behavior)
            # Type checker sees: list[tuple[str, str | None]]
            tuples = list_servers() # [('server1', '2392839'), ('server2', '9398239')]

            # Get only server names
            # Type checker sees: list[str]
            names = list_servers(sole_names=True) # ['server1', 'server2']

            # Get only server IDs
            # Type checker sees: list[str | None]
            ids = list_servers(sole_ids=True) # ['2392839', '9398239']
            ```
        """

        servers = []
        for p in (self.project_path / "servers").iterdir():
            if not p.is_dir():
                continue

            if ":" in p.name:
                name, server_id = p.name.split(":", 1)
            else:
                name, server_id = p.name, None

            if sole_names:
                servers.append(name)
            elif sole_ids:
                servers.append(server_id)
            else:
                servers.append((name, server_id))

        return servers

    def create_server(self, server: str | KherimoyaServer) -> KherimoyaServer:
        """
        Creates a new server from a string for the name, or a nonexisting KherimoyaServer

        Args:
            server (str | KherimoyaServer): A name for the server, or a nonexisting KherimoyaServer

        Returns:
            KherimoyaServer: The new, existing server.

        Example:
            ```
            # Create a server from a name
            server1 = ServerManager.create_server("newserver1")

            # Create a server from a nonexisting KherimoyaServer
            server2 = KherimoyaServer(PROJECT_PATH, "newserver2")
            server2 = ServerManager.create_server(server2)
            ```
        """
        if isinstance(server, KherimoyaServer):
            if server.exists:
                raise FileExistsError("Server already exists")
            new_server = server
        else:
            new_server = KherimoyaServer(self.project_path, server)

        if new_server.exists:
            raise FileExistsError("Server already exists")
        elif new_server.name in self.list_servers(sole_names=True) and self.strict_names:
            raise FileExistsError("Server name is already used")

        # - set up the server - #
        new_server._server_id = str(self._generate_unique_id())

        base_path = (self.project_path / "servers" / f"{new_server.name}:{new_server.server_id}").resolve()
        base_path.mkdir(parents=False, exist_ok=False)

        # - make the filestructure - #
        for subdir in ["config", "extra", "server", "state"]:
            (base_path / subdir).mkdir()

        new_server.refresh(base_path)

        # - set up with Endstone - #

        screen_name = f'{new_server.name}:{new_server.server_id}'

        # screen -dmS "$SERVER_SCREEN_NAME" endstone -y -s "$BASE_PATH" -- this is what we're doing
        subprocess.Popen(["screen", "-dmS", screen_name, "endstone", "-y", "-s", str(base_path)]) # starting an endstone server in an empty directory will cause it to create a new server, then starts the server
        
        time.sleep(1) # a second is good
        while not Path(base_path / "server" / "worlds").is_dir(): # when a BDS server is started for the first time, it generates a number of directories, one being worlds/
            time.sleep(1) # we wait until the server is started, which is when the server has started
        time.sleep(1) # wait an extra second for good measure
        
        # screen -Rd "$SERVER_SCREEN_NAME" -X stuff "stop $(printf '\r')" -- this is what we're doing
        subprocess.Popen(["sdaijsijdi\nscreen", "-Rd", screen_name, "-X", "stuff", '"stop\n"']) # the beginning gibberish invalidates the past command, if the user was typing something in

        with open(base_path / "state" / "state.json", "w", encoding="utf-8") as f:
            json.dump({"running": False}, f, indent=4) 
 
        return new_server

    def _generate_unique_id(self) -> str:
        existing = self.list_servers(sole_ids=True)
        while True:
            new_id = str(uuid.uuid4())
            if new_id not in existing:
                return new_id