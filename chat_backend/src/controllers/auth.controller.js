import { pool } from '../lib/db.js';
import { generateToken } from '../lib/utils.js';

export const signup = async (req,res) => 
    { 
        try
        {
            const {name, email, password} = req.body;

            if (!name || !email || !password)
                return res.status(400).json("All fields are required\n"); 

            if (password.length < 6)
                return res.status(400).json("Password must be six characters or greater");

            // Add further validations if necessary

            let result = await pool.query("SELECT * from Users where name = $1 and email = $2",[name,email]);

            if (result.rows.length > 0)
                return res.status(409).json("User already exists");
            
            result = await pool.query("INSERT INTO Users (name, email, password) values($1,$2,$3) RETURNING *;",[name,email,password]);

            // Function that generates token and sends it as a cookie through the res object

            const id = result.rows[0].user_id;
            const token = generateToken(result.rows[0].user_id,res);

            return res.status(200).json({
                "success": true,
                "user": {
                "id": id,
                "name": name,
                "email": email
                },
                token
            });
        }
        catch (error)
        {
            console.error("Error in signup : ",error);
            res.status(500).json({message:"Internal Server Error"});
        }
    };

export const login = async (req,res) => 
    {
        const {email, password} = req.body;
       
        try
        {
            let result = await pool.query("SELECT * from Users where email = $1 and password = $2",[email,password]);
           
            // user does not exist
            if (result.rows.length == 0) 
               return res.status(401).json({message: "Invalid Credentials"});

            // user exists

            const id = result.rows[0].user_id.toString();
            const fullname = result.rows[0].name;
            const token = generateToken(result.rows[0].user_id,res);

            return res.status(200).json({
                "success": true,
                "user": {
                "id": id,
                "name": fullname,
                "email": email
                },
                token
            });

        }
        
        catch (error)
        {
            console.error("Error in Signin: ",error);
        }
    };

export const logout = async (_,res) => 
    {
        res.cookie("jwt","",{maxAge:0});
        return res.status(200).json({message: "Logged out successfully"});   
    };

// to update any information probably profile pictures and stuff
export const updateProfile = async (req,res) => {};
