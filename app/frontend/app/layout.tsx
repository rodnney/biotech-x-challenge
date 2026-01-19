import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Biotech-X Platform",
  description: "Plataforma de análise de espectrometria de massa",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="pt-BR">
      <body>{children}</body>
    </html>
  );
}
