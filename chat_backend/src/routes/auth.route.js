import express from 'express';

const router = express.Router();

router.get("/signup", (req,res) => {res.send("Signup Endpoint");});

router.get("/signin", (req,res) => {res.send("Signin Endpoint");});

router.get("/login", (req,res) => {res.send("Login Endpoint");});

export default router;
