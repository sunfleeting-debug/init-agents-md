// Undocumented public function
export function add(a: number, b: number): number {
    return a + b;
}

// Documented public function
/** Multiplies two numbers. */
export function multiply(a: number, b: number): number {
    return a * b;
}

// Internal (not exported)
function internalHelper(): void {
    return;
}
