import jwt from 'jsonwebtoken';
export function auth(req,res,next){try{const h=req.headers.authorization||'';if(!h.startsWith('Bearer '))return res.status(401).json({message:'Authentication required'});const secret=process.env.JWT_SECRET||'conference-app-secret-jwt-key-2026';req.user=jwt.verify(h.slice(7),secret);next()}catch(e){return res.status(401).json({message:'Invalid or expired token'})}}
export const roles=(...allowed)=>(req,res,next)=>allowed.includes(req.user?.role)?next():res.status(403).json({message:'Forbidden'});
export function errorHandler(err,req,res,next){console.error(err);res.status(err.status||500).json({message:err.message||'Internal server error'});}
