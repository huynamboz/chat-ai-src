import { env } from "./utils/env-loader.js"
import initSocket from "./app/Message/socket/message.socket.js"
import errorHandler from "./middlewares/error-handler.js"
import connectDB from "./db/connect.db.js"
import routes from "./app/index.routes.js"

import { urlencoded } from "express"
import { Server } from "socket.io"
import express from "express"
import http from "http"
import cors from "cors"


const app = express()
const httpServer = http.createServer(app)
const io = new Server(httpServer, {
    cors: {
        origin: "*",
        methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
        allowedHeaders: ["*"],
        credentials: false
    }
})

app.set("trust proxy", true)
app.use(cors({
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowedHeaders: ["*"],
    credentials: false
}))
app.use(express.json())
app.use(express.static("public"))
app.use(urlencoded({extended: true}))

// app.use((req, res, next) =>{
//     console.log(req.path, res.method)
//     next()
// })

await connectDB()

routes(app)
initSocket(io)

app.use(errorHandler)

httpServer.listen(env.PORT, () => {
    const baseURL = `${env.HOST}:${env.PORT}`
    console.log(`Listening on port ${env.PORT}`)
    console.log(`--> Test page: ${baseURL}/test-ws`)
})

