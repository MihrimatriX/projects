import Link from "next/link";
import { IconChevronLeft } from "@/components/icons";

type Props = {
  href?: string;
  label?: string;
};

export default function PageBack({ href = "/", label = "Okuma listesi" }: Props) {
  return (
    <Link href={href} className="page-back">
      <IconChevronLeft />
      {label}
    </Link>
  );
}
