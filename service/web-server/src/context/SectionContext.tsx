import { Section } from "@/components/section-switcher";
import { createContext, PropsWithChildren, useState } from "react";

export interface SectionContextType {
  activeSection: Section;
  setActiveSection: React.Dispatch<React.SetStateAction<Section>>;
}

export const SectionContext = createContext<SectionContextType>({
  activeSection: {} as Section,
  setActiveSection: () => {},
});

export function SectionProvider({
  children,
  sections,
}: PropsWithChildren<{ sections: Section[] }>) {
  const [activeSection, setActiveSection] = useState<Section>(sections[0]);

  return (
    <SectionContext.Provider value={{ activeSection, setActiveSection }}>
      {children}
    </SectionContext.Provider>
  );
}
