import aj from '../lib/arcjet.js';
import { isSpoofedBot } from "@arcjet/inspect";

export const arcjetProtection = async (req,res,next) => 
{
 try
 {
    const decision = await aj.protect(req);
 
    if (decision.isDenied())
    {
        if (decision.reason.isRateLimit())
            res.status(429).json({message: "Access denied due to rate limit"});
        else if (decision.reason.isBot())
            res.status(403).json({message: "Bot access denied"});
        else
            res.status(403).json({message: "Access denied due to security policy"});
    }

    next();
 } 

 catch(error)
 {
    console.log("Arcjet protection error: ",error);
    next();
 } 
}