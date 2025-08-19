export function createPublicClient(){ return { auth: { getSession: async ()=>({data:{session:null}}), signInWithOtp: ()=>{}, signOut: ()=>{} } } }
export function createSSRClient(cookies:any){ return { auth: { getSession: async ()=>({data:{session:null}}) } } }
