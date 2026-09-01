import "dotenv/config";
import { prisma } from "../src/prisma";

type Preset = { id: string; name: string; icon: string; color: string };

const expense: Preset[] = [
  { id: "cat_makan", name: "Makan", icon: "restaurant", color: "#F97316" },
  { id: "cat_transport", name: "Transport", icon: "directions_car", color: "#3B82F6" },
  { id: "cat_belanja", name: "Belanja", icon: "shopping_bag", color: "#A855F7" },
  { id: "cat_listrik", name: "Listrik", icon: "bolt", color: "#EAB308" },
  { id: "cat_air", name: "Air", icon: "water_drop", color: "#06B6D4" },
  { id: "cat_internet", name: "Internet", icon: "wifi", color: "#6366F1" },
  { id: "cat_kesehatan", name: "Kesehatan", icon: "local_hospital", color: "#EF4444" },
  { id: "cat_hiburan", name: "Hiburan", icon: "movie", color: "#EC4899" },
  { id: "cat_pendidikan", name: "Pendidikan", icon: "school", color: "#8B5CF6" },
  { id: "cat_cicilan", name: "Cicilan", icon: "credit_card", color: "#F43F5E" },
  { id: "cat_lainnya_expense", name: "Lainnya", icon: "more_horiz", color: "#6B7280" },
];

const income: Preset[] = [
  { id: "cat_gaji", name: "Gaji", icon: "work", color: "#10B981" },
  { id: "cat_freelance", name: "Freelance", icon: "laptop", color: "#14B8A6" },
  { id: "cat_investasi", name: "Investasi", icon: "trending_up", color: "#22C55E" },
  { id: "cat_hadiah", name: "Hadiah", icon: "card_giftcard", color: "#F59E0B" },
  { id: "cat_lainnya_income", name: "Lainnya", icon: "more_horiz", color: "#6B7280" },
];

async function main() {
  const presets = [
    ...expense.map((c) => ({ ...c, type: "expense" as const })),
    ...income.map((c) => ({ ...c, type: "income" as const })),
  ];

  // id di-hardcode supaya upsert idempotent: seeder ini jalan tiap container start.
  for (const { id, ...data } of presets) {
    await prisma.category.upsert({
      where: { id },
      update: data,
      create: { id, ...data, userId: null, isDefault: true },
    });
  }

  console.log(`Seed selesai: ${presets.length} kategori preset`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
