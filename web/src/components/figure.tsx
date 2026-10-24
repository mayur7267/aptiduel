// Question figures are SVG strings from our own seed data. Anything that
// isn't plain drawing markup is refused, as a guard against bad data.
const UNSAFE = /<script|<foreignObject|<iframe|<image|<use|\son\w+\s*=|javascript:|href\s*=/i;

// Pass `label` for a figure that stands alone; leave it out when the
// surrounding control (an option button) already names it.
export function Figure({ svg, label, className = "" }: { svg: string; label?: string; className?: string }) {
  if (!svg.trimStart().startsWith("<svg") || UNSAFE.test(svg)) return null;
  return (
    <div
      {...(label ? { role: "img", "aria-label": label } : { "aria-hidden": true })}
      className={`[&>svg]:block [&>svg]:h-full [&>svg]:w-full ${className}`}
      dangerouslySetInnerHTML={{ __html: svg }}
    />
  );
}
