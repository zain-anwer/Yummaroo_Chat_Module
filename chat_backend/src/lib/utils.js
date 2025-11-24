import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';

dotenv.config();

export const generateToken = (userId,res) =>
{
    const token = jwt.sign({userId},process.env.JWT_SECRET,{expiresIn : "7d"});
      
    res.cookie("jwt",token,
        {
            maxAge: 7 * 24 * 60 * 60 * 1000,
            httpOnly: true,
            sameSite: "strict",
            secure: (process.env.NODE_ENV === "development") ? false : true        
        }
    );

    return token;
};

export const verifyToken = async (req,res) =>
{
    try
    {
         // Read token from header (mobile apps, sockets)
        const authHeader = req.headers.authorization;
        let token = authHeader?.startsWith("Bearer ")
        ? authHeader.split(" ")[1]
        : null;

        // Fallback: read token from cookie (browser website)
        if (!token) {
        token = req.cookies?.jwt;
        }
        
        if (!token) 
            return res.status(401).json({message: "Unauthorized - No token provided"});
        const decoded = jwt.verify(token,process.env.JWT_SECRET);
        if (!decoded)
            return res.status(401).json({message: "Unauthorized - Invalid Token"});

        let result = await pool.query("SELECT * from Users where user_id = $1;",[decoded.userId]);
        if (result.rows.length == 0)
            return res.status(401).json({message: "User not found"});

        return decoded.userId;
    }
    catch(error)
    {
        console.error("Error in authorization middleware - protectRoute");
        return res.send(500).json({message:"Internal Server Error"});
    }
};