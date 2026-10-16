// A modal dialog with a title, used by the admin pages. `wide` for tables and
// long details.
export default function Dialog({ title, children, wide = false }) {
  return (
    <div className="dialog-backdrop">
      <div className={wide ? 'dialog wide' : 'dialog'} role="dialog" aria-modal="true" aria-label={title}>
        <h2>{title}</h2>
        {children}
      </div>
    </div>
  );
}
