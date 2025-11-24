import dotenv from "dotenv";
import jwt from "jsonwebtoken";
import {pool} from "../lib/db.js";

dotenv.config();

export const protectRoute = async (req,res,next) =>
{
    try
    {
        // const token = req.cookies.jwt;
        let token;

        if (req.headers.authorization && req.headers.authorization.startsWith("Bearer")) {
            token = req.headers.authorization.split(" ")[1];
        } 
        else if (req.cookies.jwt) {
            token = req.cookies.jwt;
        }
        
        if (!token) 
            return res.status(401).json({message: "Unauthorized - No token provided"});
        const decoded = jwt.verify(token,process.env.JWT_SECRET);
        if (!decoded)
            return res.status(401).json({message: "Unauthorized - Invalid Token"});

        let result = await pool.query("SELECT * from Users where user_id = $1;",[decoded.userId]);
        if (result.rows.length == 0)
            return res.status(401).json({message: "User not found"});

        req.userId = decoded.userId;
        next();
    }
    catch(error)
    {
        console.error("Error in authorization middleware - protectRoute");
        return res.send(500).json({message:"Internal Server Error"});
    }
};