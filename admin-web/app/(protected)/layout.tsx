import { Nav } from "@/components/Nav";

// Korumali alan duzeni. Oturum kontrolu middleware'de yapilir.
export default function ProtectedLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen">
      <Nav />
      <main className="mx-auto max-w-6xl px-4 py-6">{children}</main>
    </div>
  );
}
