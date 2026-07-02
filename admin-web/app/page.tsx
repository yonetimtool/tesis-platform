import { redirect } from "next/navigation";

// Kok: korumali alana yonlendir (middleware oturum yoksa /login'e ceker).
export default function Home() {
  redirect("/dashboard");
}
