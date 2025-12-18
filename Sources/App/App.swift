import Vapor
@preconcurrency import MongoSwift
import Foundation

// ==========================================
// ⚙️ CONFIGURACIÓN FIJA (Leída del .env)
// ==========================================
let GIT_REPO  = (Environment.get("GIT_REPO") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
let GIT_USER  = (Environment.get("GIT_USER") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
let GIT_EMAIL = (Environment.get("GIT_EMAIL") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
// ==========================================

struct GitInput: Content {
    let token: String
}

struct Usuario: Content, @unchecked Sendable {
    let _id: BSONObjectID?
    let nombre: String
    let rol: String
}

@main
struct App {
    static func main() async throws {
        let env = try Environment.detect()
        let app = try await Application.make(env)
        
        let mongoClient = try MongoClient("mongodb://mongo:27017", using: app.eventLoopGroup)
        defer { try? mongoClient.syncClose() }
        let db = mongoClient.db("mi_base_de_datos")
        let collection = db.collection("usuarios", withType: Usuario.self)

        let cssCommon = "body{margin:0;min-height:100vh;display:flex;flex-direction:column;align-items:center;background:linear-gradient(135deg,#1e3c72,#2a5298);font-family:system-ui,sans-serif;color:white;padding:20px}.card{background:rgba(255,255,255,0.1);padding:2rem;border-radius:20px;backdrop-filter:blur(10px);text-align:center;max-width:800px;width:100%;margin-bottom:20px}button{padding:12px;border-radius:8px;border:none;font-weight:bold;cursor:pointer;margin-top:5px;width:100%}.btn-blue{background:#0984e3;color:white}.btn-purple{background:#6c5ce7;color:white}.btn-green{background:#00b894;color:white}.btn-red{background:#d63031;color:white}.btn-yellow{background:#f1c40f;color:black}input{padding:12px;border-radius:8px;border:none;width:100%;margin-bottom:10px}table{width:100%;margin-top:10px;background:rgba(0,0,0,0.2);border-radius:10px}th,td{padding:10px;text-align:left;border-bottom:1px solid rgba(255,255,255,0.1)}"

        do {
            // HOME
            app.get { req -> Response in
                let html = """
                <!DOCTYPE html><html><head><meta charset="UTF-8"><style>\(cssCommon)</style></head><body>
                <div class="card"><h1>🏠 Panel Seguro</h1><a href="/usuarios"><button class="btn-blue">👥 Gestionar Usuarios</button></a></div>
                <div class="card"><h2>☁️ GitHub</h2>
                <h3> Token git: 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  </h3>
                <p style="font-size:0.9rem;opacity:0.8">Introduce tu Token:</p>
                <input type="password" id="gitTokenInput" placeholder="ghp_..." style="background:rgba(0,0,0,0.3);color:white;text-align:center">
                <button class="btn-purple" onclick="sincronizarGit()">🚀 Sincronizar Ahora</button>
                <div id="status" style="margin-top:10px;white-space:pre-wrap;display:none;background:#2d3436;padding:10px;text-align:left;font-family:monospace;font-size:0.8rem"></div></div>
                <script>
                async function sincronizarGit(){
                    const t=document.getElementById('gitTokenInput').value;if(!t)return alert("¡Falta el Token!");
                    const d=document.getElementById('status');d.style.display='block';d.innerText="⏳ Conectando...";
                    try{const r=await fetch('/api/git/sync',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({token:t})});d.innerText=await r.text();}catch(e){d.innerText="Error: "+e;}
                }
                </script></body></html>
                """
                return Response(status: .ok, headers: ["Content-Type": "text/html"], body: .init(string: html))
            }

            // USUARIOS
            app.get("usuarios") { req -> Response in
                let html = """
                <!DOCTYPE html><html><head><meta charset="UTF-8"><style>\(cssCommon)</style></head><body>
                <div style="width:100%;max-width:800px;text-align:left;margin-bottom:10px"><a href="/"><button class="btn-blue" style="width:auto">⬅ Inicio</button></a></div>
                <div class="card"><h2>Nuevo</h2><div style="display:flex;gap:10px"><input id="n" placeholder="Nombre"><input id="r" placeholder="Rol"></div><button class="btn-green" onclick="crear()">Guardar</button></div>
                <div class="card"><h2>Lista</h2><table id="t"><thead><tr><th>Nombre</th><th>Rol</th><th>Acción</th></tr></thead><tbody></tbody></table></div>
                <script>
                cargar();
                async function cargar(){const r=await fetch('/api/usuarios');const d=await r.json();let h='';if(d.length===0){h='<tr><td colspan="3" style="text-align:center;opacity:0.7">Vacío</td></tr>'}else{d.forEach(u=>{h+=`<tr><td>${u.nombre}</td><td>${u.rol}</td><td><button class="btn-yellow" style="width:auto" onclick="window.location.href='/usuarios/e/${u.id||u._id}'">✏️</button> <button class="btn-red" style="width:auto" onclick="borrar('${u.id||u._id}')">🗑️</button></td></tr>`})};document.querySelector('#t tbody').innerHTML=h;}
                async function crear(){const n=document.getElementById('n').value,r=document.getElementById('r').value;if(!n)return;await fetch('/api/usuarios',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({nombre:n,rol:r})});cargar();document.getElementById('n').value='';document.getElementById('r').value='';}
                async function borrar(i){if(confirm('¿Borrar?'))await fetch('/api/usuarios/'+i,{method:'DELETE'});cargar();}
                </script></body></html>
                """
                return Response(status: .ok, headers: ["Content-Type": "text/html"], body: .init(string: html))
            }

            // EDITAR
            app.get("usuarios", "e", ":id") { req -> Response in
                guard let id = req.parameters.get("id") else { return Response(status: .badRequest) }
                let html = """
                <!DOCTYPE html><html><head><meta charset="UTF-8"><style>\(cssCommon)</style></head><body>
                <div class="card"><h1>✏️ Editar</h1><input id="n"><input id="r"><div style="display:flex;gap:10px"><button class="btn-red" onclick="window.location.href='/usuarios'">Cancelar</button><button class="btn-green" onclick="save()">Guardar</button></div></div>
                <script>
                const id="\(id)";fetch('/api/usuarios/'+id).then(r=>r.json()).then(u=>{document.getElementById('n').value=u.nombre;document.getElementById('r').value=u.rol});
                async function save(){const n=document.getElementById('n').value,r=document.getElementById('r').value;await fetch('/api/usuarios/'+id,{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify({nombre:n,rol:r})});window.location.href='/usuarios';}
                </script></body></html>
                """
                return Response(status: .ok, headers: ["Content-Type": "text/html"], body: .init(string: html))
            }

            // ==========================================
            // API GIT (CON SANITIZACIÓN DE ENTRADAS)
            // ==========================================
            app.post("api", "git", "sync") { req -> String in
                let input = try req.content.decode(GitInput.self)
                // LIMPIEZA AUTOMÁTICA
                let tokenWeb = input.token.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if tokenWeb.isEmpty { return "ERROR: El token está vacío." }
                if GIT_REPO.isEmpty { return "ERROR: Falta GIT_REPO en el archivo .env" }

                // Construimos la URL segura (USA LA VARIABLE tokenWeb, NO ESCRIBAS TU CLAVE AQUÍ)
                let remoteUrl = "https://\(GIT_USER):\(tokenWeb)@\(GIT_REPO)"
                
                let script = """
                cd /app
                git config --global user.email "\(GIT_EMAIL)"
                git config --global user.name "\(GIT_USER)"
                git config --global --add safe.directory /app
                
                # PROTECCIÓN .gitignore
                echo ".build/" > .gitignore
                echo ".swiftpm/" >> .gitignore
                echo "mongo-data/" >> .gitignore
                echo ".env" >> .gitignore

                # REINICIO LIMPIO
                rm -rf .git
                git init
                git remote add origin "\(remoteUrl)"
                git add .
                git commit -m "Update desde Web"
                
                # SUBIDA
                export GIT_CURL_VERBOSE=1
                git push -u --force origin master 2>&1
                """
                return shell(script)
            }

            // API CRUD
            app.get("api", "usuarios") { req in try await collection.find().toArray() }
            app.post("api", "usuarios") { req -> Usuario in
                let d = try req.content.decode(Usuario.self)
                let u = Usuario(_id: d._id ?? BSONObjectID(), nombre: d.nombre, rol: d.rol)
                try await collection.insertOne(u); return u
            }
            app.get("api", "usuarios", ":id") { req -> Usuario in
                guard let id = req.parameters.get("id"), let o = try? BSONObjectID(id), let u = try await collection.findOne(["_id": BSON.objectID(o)]) else { throw Abort(.notFound) }; return u
            }
            app.put("api", "usuarios", ":id") { req -> Usuario in
                guard let id = req.parameters.get("id"), let o = try? BSONObjectID(id) else { throw Abort(.badRequest) }
                let d = try req.content.decode(Usuario.self)
                let uDoc: BSONDocument = ["nombre": BSON.string(d.nombre), "rol": BSON.string(d.rol)]
                guard let r = try await collection.findOneAndUpdate(filter: ["_id": BSON.objectID(o)], update: ["$set": BSON.document(uDoc)], options: FindOneAndUpdateOptions(returnDocument: .after)) else { throw Abort(.notFound) }; return r
            }
            app.delete("api", "usuarios", ":id") { req -> HTTPStatus in
                guard let id = req.parameters.get("id"), let o = try? BSONObjectID(id) else { throw Abort(.badRequest) }; _ = try await collection.deleteOne(["_id": BSON.objectID(o)]); return .ok
            }

            try await app.execute()
        } catch { app.logger.report(error: error) }
        try await app.asyncShutdown()
    }
}

@discardableResult
func shell(_ command: String) -> String {
    let task = Process()
    let pipe = Pipe()
    task.standardOutput = pipe; task.standardError = pipe
    task.arguments = ["-c", command]; task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.standardInput = FileHandle.nullDevice
    try? task.run(); let d = pipe.fileHandleForReading.readDataToEndOfFile(); task.waitUntilExit()
    return String(data: d, encoding: .utf8) ?? ""
}