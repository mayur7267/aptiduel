"use client";

import { useEffect, useRef, type ReactNode } from "react";
import { Close } from "./icons";

// A dialog over the page: Escape or the close button dismisses it.
export function Modal({
  open,
  onClose,
  title,
  children,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
}) {
  const dialog = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const d = dialog.current;
    if (!d) return;
    if (open && !d.open) d.showModal();
    if (!open && d.open) d.close();
  }, [open]);

  return (
    <dialog
      ref={dialog}
      onClose={onClose}
      aria-label={title}
      className="m-auto max-h-[calc(100dvh-40px)] w-[min(560px,calc(100vw-24px))] rounded-[22px] border-2 border-line bg-surface p-0 text-text sticker backdrop:bg-ink/75 backdrop:backdrop-blur-sm"
    >
      {open && (
        <div className="flex flex-col gap-5 p-5 sm:p-6">
          <div className="flex items-center justify-between gap-3">
            <h2 className="font-display text-xl font-bold">{title}</h2>
            <button
              onClick={onClose}
              aria-label="Close"
              className="flex size-9 items-center justify-center rounded-full border border-line hover:bg-raised"
            >
              <Close size={16} strokeWidth={2.4} />
            </button>
          </div>
          {children}
        </div>
      )}
    </dialog>
  );
}
