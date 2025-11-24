// code: {pool} from "chat_backend/src/lib/db.js";
// run the above import line to get the pool object to run queries


import dotenv from 'dotenv';
import pkg from 'pg';

dotenv.config();

// It extracts the class Pool from the pkg object to be used later to create pool objects
const { Pool } = pkg;
export const pool = new Pool({connectionString : process.env.PG_URI});