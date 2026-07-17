import { AppShell } from "@/components/AppShell";
import { ToastProvider } from "@/components/Toast";

// Korumali alan duzeni. Oturum kontrolu middleware'de yapilir.
export default function ProtectedLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <ToastProvider>
      <AppShell>{children}</AppShell>
    </ToastProvider>
  );
}
