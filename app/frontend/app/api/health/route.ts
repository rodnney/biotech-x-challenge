import { NextResponse } from "next/server";

export async function GET() {
  return NextResponse.json({
    status: "healthy",
    message: "Frontend funcionando corretamente",
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || "development",
  });
}
