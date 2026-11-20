// Builds the Coding section's questions and writes supabase/seed-coding.sql.
//
// Each question is a small program, written once as a tree and printed in
// C, C++, Java, Python and pseudocode, so players read it in the language
// they know and two players with different languages can share a duel.
//
// Nothing here is guessed: every program is compiled and run with the
// real gcc/clang, g++, javac and python3, and a question is kept only when
// all four print exactly what our own evaluator printed (pseudocode is the
// same tree, so it is covered by that agreement). The wrong options are
// the outputs of the same program with a typical slip in it (a loop that
// runs once more, < for <=, a forgotten break), so each one is a mistake a
// student really makes.
//
// Run from the repo root:  node scripts/generate-coding.ts
// Needs: cc, c++, javac + java, python3 on PATH.

import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// ---------------------------------------------------------------------
// The program tree
// ---------------------------------------------------------------------

type Op = '+' | '-' | '*' | '/' | '%' | '<' | '<=' | '>' | '>=' | '==' | '!=' | '&&' | '||' | '&' | '|' | '^' | '<<' | '>>';
type E =
  | { k: 'n'; v: number }
  | { k: 'v'; n: string }
  | { k: 'b'; op: Op; a: E; b: E }
  | { k: 'at'; arr: string; i: E }
  | { k: 'call'; f: string; args: E[] };
type S =
  | { k: 'let'; n: string; e: E }
  | { k: 'arr'; n: string; vals: number[] }
  | { k: 'set'; n: string; e: E }
  | { k: 'aug'; n: string; op: '+' | '-' | '*' | '/' | '%'; e: E }
  | { k: 'setAt'; arr: string; i: E; e: E }
  | { k: 'print'; e: E }
  | { k: 'for'; v: string; from: E; to: E; step: number; body: S[] } // `to` is inclusive
  | { k: 'while'; c: E; body: S[] }
  | { k: 'if'; c: E; then: S[]; else?: S[] }
  | { k: 'break' }
  | { k: 'continue' }
  | { k: 'ret'; e: E };
type Fn = { name: string; params: string[]; body: S[] };
type Prog = { fns: Fn[]; main: S[] };

const n = (v: number): E => ({ k: 'n', v });
const v = (name: string): E => ({ k: 'v', n: name });
const b = (a: E | number | string, op: Op, c: E | number | string): E => ({ k: 'b', op, a: ex(a), b: ex(c) });
const ex = (x: E | number | string): E => (typeof x === 'number' ? n(x) : typeof x === 'string' ? v(x) : x);
const at = (arr: string, i: E | number | string): E => ({ k: 'at', arr, i: ex(i) });
const call = (f: string, ...args: (E | number | string)[]): E => ({ k: 'call', f, args: args.map(ex) });
const let_ = (name: string, e: E | number | string): S => ({ k: 'let', n: name, e: ex(e) });
const arr = (name: string, vals: number[]): S => ({ k: 'arr', n: name, vals });
const set = (name: string, e: E | number | string): S => ({ k: 'set', n: name, e: ex(e) });
const aug = (name: string, op: '+' | '-' | '*' | '/' | '%', e: E | number | string): S => ({ k: 'aug', n: name, op, e: ex(e) });
const setAt = (a: string, i: E | number | string, e: E | number | string): S => ({ k: 'setAt', arr: a, i: ex(i), e: ex(e) });
const print = (e: E | number | string): S => ({ k: 'print', e: ex(e) });
const for_ = (name: string, from: E | number | string, to: E | number | string, body: S[], step = 1): S =>
  ({ k: 'for', v: name, from: ex(from), to: ex(to), step, body });
const while_ = (c: E, body: S[]): S => ({ k: 'while', c, body });
const if_ = (c: E, then: S[], else_?: S[]): S => ({ k: 'if', c, then, else: else_ });
const brk: S = { k: 'break' };
const cont: S = { k: 'continue' };
const ret = (e: E | number | string): S => ({ k: 'ret', e: ex(e) });

// ---------------------------------------------------------------------
// Our own evaluator (C semantics; the real runs check it)
// ---------------------------------------------------------------------

class Reject extends Error {}
class Break {}
class Continue {}
class Return {
  value: number;
  constructor(value: number) {
    this.value = value;
  }
}

const MAX_INT = 2 ** 31 - 1;

function evaluate(p: Prog, watch?: string): { out: string; trace: number[] } | null {
  const fns = new Map(p.fns.map((f) => [f.name, f]));
  const printed: number[] = [];
  const trace: number[] = [];
  let steps = 0;
  let depth = 0;
  const tick = () => {
    if (++steps > 20000) throw new Reject('too long');
  };
  const checked = (x: number) => {
    if (!Number.isInteger(x) || Math.abs(x) > MAX_INT) throw new Reject('overflow');
    return x;
  };

  function val(e: E, env: Map<string, number | number[]>): number {
    switch (e.k) {
      case 'n':
        return e.v;
      case 'v': {
        const x = env.get(e.n);
        if (typeof x !== 'number') throw new Reject(`unknown ${e.n}`);
        return x;
      }
      case 'at': {
        const a = env.get(e.arr);
        const i = val(e.i, env);
        if (!Array.isArray(a) || i < 0 || i >= a.length) throw new Reject('index');
        return a[i];
      }
      case 'call': {
        const f = fns.get(e.f);
        if (!f) throw new Reject(`no fn ${e.f}`);
        if (++depth > 200) throw new Reject('deep');
        const local = new Map<string, number | number[]>();
        f.params.forEach((name, i) => local.set(name, val(e.args[i], env)));
        try {
          run(f.body, local);
        } catch (r) {
          if (r instanceof Return) {
            depth--;
            return r.value;
          }
          throw r;
        }
        throw new Reject('no return');
      }
      case 'b': {
        // && and || short-circuit, as in every language here.
        if (e.op === '&&') return val(e.a, env) !== 0 && val(e.b, env) !== 0 ? 1 : 0;
        if (e.op === '||') return val(e.a, env) !== 0 || val(e.b, env) !== 0 ? 1 : 0;
        const x = val(e.a, env);
        const y = val(e.b, env);
        switch (e.op) {
          case '+': return checked(x + y);
          case '-': return checked(x - y);
          case '*': return checked(x * y);
          case '/':
          case '%':
            // Negative division rounds differently in Python: keep clear of it.
            if (y <= 0 || x < 0) throw new Reject('division');
            return e.op === '/' ? Math.trunc(x / y) : x % y;
          case '<': return x < y ? 1 : 0;
          case '<=': return x <= y ? 1 : 0;
          case '>': return x > y ? 1 : 0;
          case '>=': return x >= y ? 1 : 0;
          case '==': return x === y ? 1 : 0;
          case '!=': return x !== y ? 1 : 0;
          case '&': return x & y;
          case '|': return x | y;
          case '^': return x ^ y;
          case '<<':
            if (x < 0 || y < 0 || y > 20) throw new Reject('shift');
            return checked(x * 2 ** y);
          case '>>':
            if (x < 0 || y < 0) throw new Reject('shift');
            return x >> y;
        }
      }
    }
  }

  function run(body: S[], env: Map<string, number | number[]>, top = false) {
    for (const s of body) {
      tick();
      switch (s.k) {
        case 'let':
        case 'set':
          env.set(s.n, val(s.e, env));
          break;
        case 'arr':
          env.set(s.n, [...s.vals]);
          break;
        case 'aug': {
          const cur = val(v(s.n), env);
          env.set(s.n, val({ k: 'b', op: s.op, a: n(cur), b: s.e }, env));
          break;
        }
        case 'setAt': {
          const a = env.get(s.arr);
          const i = val(s.i, env);
          if (!Array.isArray(a) || i < 0 || i >= a.length) throw new Reject('index');
          a[i] = checked(val(s.e, env));
          break;
        }
        case 'print':
          printed.push(val(s.e, env));
          break;
        case 'for': {
          const to = val(s.to, env);
          for (let i = val(s.from, env); s.step > 0 ? i <= to : i >= to; i += s.step) {
            tick();
            env.set(s.v, i);
            try {
              run(s.body, env);
            } catch (c) {
              if (c instanceof Break) break;
              if (!(c instanceof Continue)) throw c;
            }
            if (top && watch !== undefined && env.has(watch)) trace.push(env.get(watch) as number);
          }
          env.delete(s.v);
          break;
        }
        case 'while':
          while (val(s.c, env) !== 0) {
            tick();
            try {
              run(s.body, env);
            } catch (c) {
              if (c instanceof Break) break;
              if (!(c instanceof Continue)) throw c;
            }
            if (top && watch !== undefined && env.has(watch)) trace.push(env.get(watch) as number);
          }
          break;
        case 'if':
          if (val(s.c, env) !== 0) run(s.then, env);
          else if (s.else) run(s.else, env);
          break;
        case 'break':
          throw new Break();
        case 'continue':
          throw new Continue();
        case 'ret':
          throw new Return(val(s.e, env));
      }
    }
  }

  try {
    run(p.main, new Map(), true);
  } catch (e) {
    if (e instanceof Reject || e instanceof Break || e instanceof Continue || e instanceof Return) return null;
    throw e;
  }
  if (printed.length === 0) return null;
  return { out: printed.join(' '), trace };
}

// ---------------------------------------------------------------------
// Printing the tree in each language
// ---------------------------------------------------------------------

type Lang = 'c' | 'cpp' | 'java' | 'python' | 'pseudo';
const LANGS: Lang[] = ['c', 'cpp', 'java', 'python', 'pseudo'];

// Higher binds tighter. Python ranks & ^ | above comparisons, C below.
const PREC_C: Record<Op, number> = {
  '*': 10, '/': 10, '%': 10, '+': 9, '-': 9, '<<': 8, '>>': 8,
  '<': 7, '<=': 7, '>': 7, '>=': 7, '==': 6, '!=': 6, '&': 5, '^': 4, '|': 3, '&&': 2, '||': 1,
};
const PREC_PY: Record<Op, number> = {
  '*': 10, '/': 10, '%': 10, '+': 9, '-': 9, '<<': 8, '>>': 8, '&': 7, '^': 6, '|': 5,
  '<': 4, '<=': 4, '>': 4, '>=': 4, '==': 4, '!=': 4, '&&': 2, '||': 1,
};
const COMPARE = new Set<Op>(['<', '<=', '>', '>=', '==', '!=']);
const BITWISE = new Set<Op>(['&', '|', '^']);

function opText(op: Op, lang: Lang): string {
  if (lang === 'python') return op === '/' ? '//' : op === '&&' ? 'and' : op === '||' ? 'or' : op;
  if (lang === 'pseudo') return op === '%' ? 'mod' : op === '&&' ? 'and' : op === '||' ? 'or' : op;
  return op;
}

type Names = (f: string) => string;

function expr(e: E, lang: Lang, names: Names, parentPrec = 0, right = false): string {
  switch (e.k) {
    case 'n':
      return String(e.v);
    case 'v':
      return e.n;
    case 'at':
      return `${e.arr}[${expr(e.i, lang, names)}]`;
    case 'call':
      return `${names(e.f)}(${e.args.map((a) => expr(a, lang, names)).join(', ')})`;
    case 'b': {
      const prec = (lang === 'python' ? PREC_PY : PREC_C)[e.op];
      const text = `${expr(e.a, lang, names, prec)} ${opText(e.op, lang)} ${expr(e.b, lang, names, prec, true)}`;
      // Brackets where the tree needs them, and around mixes people misread
      // (bitwise inside a comparison, a comparison inside a comparison).
      const child = e.op;
      const needs = prec < parentPrec || (right && prec === parentPrec) || (parentPrec > 0 && (BITWISE.has(child) || COMPARE.has(child)) && parentPrec !== 2 && parentPrec !== 1);
      return needs ? `(${text})` : text;
    }
  }
}

// Python's range end is exclusive: print `to + 1` (or `to - 1` counting down).
function rangeEnd(to: E, step: number, lang: Lang, names: Names): string {
  const d = step > 0 ? 1 : -1;
  if (to.k === 'n') return String(to.v + d);
  // `i - 1` up to and including → range(..., i), not range(..., i - 1 + 1).
  if (to.k === 'b' && (to.op === '+' || to.op === '-') && to.b.k === 'n') {
    const c = (to.op === '+' ? to.b.v : -to.b.v) + d;
    const base = expr(to.a, lang, names, 9);
    return c === 0 ? base : `${base} ${c > 0 ? '+' : '-'} ${Math.abs(c)}`;
  }
  return `${expr(to, lang, names, 9)} ${d > 0 ? '+' : '-'} 1`;
}

function isSimple(s: S) {
  return s.k === 'break' || s.k === 'continue' || s.k === 'ret';
}

function lines(body: S[], lang: Lang, names: Names, depth: number): string[] {
  const ind = (lang === 'python' ? '    ' : '  ').repeat(depth);
  const out: string[] = [];
  const semi = lang === 'python' || lang === 'pseudo' ? '' : ';';
  const e = (x: E) => expr(x, lang, names);
  for (const s of body) {
    switch (s.k) {
      case 'let':
        out.push(ind + (lang === 'python' ? `${s.n} = ${e(s.e)}` : lang === 'pseudo' ? `Integer ${s.n} = ${e(s.e)}` : `int ${s.n} = ${e(s.e)};`));
        break;
      case 'arr': {
        const list = s.vals.join(', ');
        out.push(ind + (lang === 'python' ? `${s.n} = [${list}]`
          : lang === 'java' ? `int[] ${s.n} = {${list}};`
          : lang === 'pseudo' ? `Integer ${s.n}[] = {${list}}`
          : `int ${s.n}[] = {${list}};`));
        break;
      }
      case 'set':
        out.push(`${ind}${s.n} = ${e(s.e)}${semi}`);
        break;
      case 'aug':
        if (lang === 'pseudo') out.push(`${ind}${s.n} = ${expr({ k: 'b', op: s.op, a: v(s.n), b: s.e }, lang, names)}`);
        else out.push(`${ind}${s.n} ${opText(s.op, lang)}= ${e(s.e)}${semi}`);
        break;
      case 'setAt':
        out.push(`${ind}${s.arr}[${e(s.i)}] = ${e(s.e)}${semi}`);
        break;
      case 'print': {
        // Wrap anything compound, so `+ " "` or `<<` can't change its meaning.
        const x = s.e.k === 'b' ? `(${e(s.e)})` : e(s.e);
        out.push(ind + (lang === 'c' ? `printf("%d ", ${e(s.e)});`
          : lang === 'cpp' ? `cout << ${x} << " ";`
          : lang === 'java' ? `System.out.print(${x} + " ");`
          : lang === 'python' ? `print(${e(s.e)}, end=" ")`
          : `print ${e(s.e)}`));
        break;
      }
      case 'for': {
        const up = s.step > 0;
        const st = Math.abs(s.step);
        if (lang === 'python') {
          const range = s.step === 1 && !(s.from.k === 'n' && s.from.v === 0)
            ? `range(${e(s.from)}, ${rangeEnd(s.to, s.step, lang, names)})`
            : s.step === 1
              ? `range(${rangeEnd(s.to, s.step, lang, names)})`
              : `range(${e(s.from)}, ${rangeEnd(s.to, s.step, lang, names)}, ${s.step})`;
          out.push(`${ind}for ${s.v} in ${range}:`);
        } else if (lang === 'pseudo') {
          out.push(`${ind}for ${s.v} = ${e(s.from)} ${up ? 'to' : 'down to'} ${e(s.to)}${st === 1 ? '' : ` step ${st}`}`);
        } else {
          const decl = `int ${s.v} = ${e(s.from)}`;
          const cond = `${s.v} ${up ? '<=' : '>='} ${e(s.to)}`;
          const inc = st === 1 ? `${s.v}${up ? '++' : '--'}` : `${s.v} ${up ? '+' : '-'}= ${st}`;
          out.push(`${ind}for (${decl}; ${cond}; ${inc}) {`);
        }
        out.push(...lines(s.body, lang, names, depth + 1));
        if (lang === 'pseudo') out.push(`${ind}end for`);
        else if (lang !== 'python') out.push(`${ind}}`);
        break;
      }
      case 'while':
        out.push(ind + (lang === 'python' ? `while ${e(s.c)}:` : lang === 'pseudo' ? `while (${e(s.c)})` : `while (${e(s.c)}) {`));
        out.push(...lines(s.body, lang, names, depth + 1));
        if (lang === 'pseudo') out.push(`${ind}end while`);
        else if (lang !== 'python') out.push(`${ind}}`);
        break;
      case 'if': {
        // `if (x) break;` on one line in the C family, as people write it.
        if (lang !== 'python' && lang !== 'pseudo' && !s.else && s.then.length === 1 && isSimple(s.then[0])) {
          out.push(`${ind}if (${e(s.c)}) ${lines(s.then, lang, names, 0)[0]}`);
          break;
        }
        let cur: S | undefined = s;
        let first = true;
        while (cur && cur.k === 'if') {
          const kw = first ? 'if' : lang === 'python' ? 'elif' : 'else if';
          if (lang === 'python') out.push(`${ind}${kw} ${e(cur.c)}:`);
          else if (lang === 'pseudo') out.push(`${ind}${kw} (${e(cur.c)})`);
          else out.push(`${ind}${first ? '' : '} '}${kw} (${e(cur.c)}) {`);
          out.push(...lines(cur.then, lang, names, depth + 1));
          first = false;
          const next: S[] | undefined = cur.else;
          if (next && next.length === 1 && next[0].k === 'if') {
            cur = next[0];
          } else {
            if (next) {
              out.push(lang === 'python' ? `${ind}else:` : lang === 'pseudo' ? `${ind}else` : `${ind}} else {`);
              out.push(...lines(next, lang, names, depth + 1));
            }
            cur = undefined;
          }
        }
        if (lang === 'pseudo') out.push(`${ind}end if`);
        else if (lang !== 'python') out.push(`${ind}}`);
        break;
      }
      case 'break':
        out.push(`${ind}break${semi}`);
        break;
      case 'continue':
        out.push(`${ind}continue${semi}`);
        break;
      case 'ret':
        out.push(`${ind}return ${e(s.e)}${semi}`);
        break;
    }
  }
  return out;
}

function fnLines(f: Fn, lang: Lang, names: Names, depth = 0): string[] {
  const ind = (lang === 'python' ? '    ' : '  ').repeat(depth);
  const params = f.params.map((p) => (lang === 'python' || lang === 'pseudo' ? p : `int ${p}`)).join(', ');
  const head = lang === 'python' ? `def ${names(f.name)}(${params}):`
    : lang === 'pseudo' ? `function ${names(f.name)}(${params})`
    : `${lang === 'java' ? 'static ' : ''}int ${names(f.name)}(${params}) {`;
  const tail = lang === 'python' ? [] : lang === 'pseudo' ? [`${ind}end function`] : [`${ind}}`];
  return [ind + head, ...lines(f.body, lang, names, depth + 1), ...tail];
}

// What the player sees: helper functions, then the statements of main,
// without the #include / class boilerplate.
function display(p: Prog, lang: Lang): string {
  const id: Names = (f) => f;
  const parts: string[] = [];
  const notes: string[] = [];
  if (lang === 'pseudo') {
    const text = JSON.stringify(p);
    if (text.includes('"op":"/"')) notes.push('// "/" is integer division: 7 / 2 = 3');
    if (text.includes('"k":"arr"')) notes.push('// Arrays start at index 0');
  }
  if (notes.length) parts.push(notes.join('\n'));
  for (const f of p.fns) parts.push(fnLines(f, lang, id).join('\n'));
  parts.push(lines(p.main, lang, id, 0).join('\n'));
  return parts.join('\n\n');
}

// ---------------------------------------------------------------------
// Running every question for real, in batches
// ---------------------------------------------------------------------

function runnable(qs: { id: number; prog: Prog }[], lang: Exclude<Lang, 'pseudo'>): string {
  const out: string[] = [];
  const mark = (id: number) =>
    lang === 'c' ? `printf("\\n@@${id}\\n");` : lang === 'cpp' ? `cout << "\\n@@${id}\\n";` : lang === 'java' ? `System.out.print("\\n@@${id}\\n");` : `print("\\n@@${id}")`;
  if (lang === 'c') out.push('#include <stdio.h>');
  if (lang === 'cpp') out.push('#include <iostream>', 'using namespace std;');
  if (lang === 'java') out.push('public class Main {');
  const depth = lang === 'java' ? 1 : 0;
  const ind = '  '.repeat(depth);
  for (const { id, prog } of qs) {
    const names: Names = (f) => `q${id}_${f}`;
    for (const f of prog.fns) out.push(...fnLines(f, lang, names, depth));
    if (lang === 'python') {
      out.push(`def q${id}():`, ...lines(prog.main, lang, names, 1), '');
    } else {
      out.push(`${ind}${lang === 'java' ? 'static ' : ''}void q${id}() {`, ...lines(prog.main, lang, names, depth + 1), `${ind}}`);
    }
  }
  if (lang === 'python') {
    out.push('import sys', 'sys.setrecursionlimit(10000)');
    for (const { id } of qs) out.push(mark(id), `q${id}()`);
  } else {
    out.push(lang === 'java' ? `${ind}public static void main(String[] args) {` : 'int main() {');
    for (const { id } of qs) out.push(`${ind}  ${mark(id)}`, `${ind}  q${id}();`);
    if (lang !== 'java') out.push('  return 0;');
    out.push(`${ind}}`);
  }
  if (lang === 'java') out.push('}');
  return out.join('\n') + '\n';
}

function parseRun(stdout: string): Map<number, string> {
  const got = new Map<number, string>();
  for (const chunk of stdout.split('\n@@').slice(1)) {
    const nl = chunk.indexOf('\n');
    got.set(Number(chunk.slice(0, nl)), chunk.slice(nl + 1).trim().replace(/\s+/g, ' '));
  }
  return got;
}

function runAll(qs: { id: number; prog: Prog }[]): Record<Exclude<Lang, 'pseudo'>, Map<number, string>> {
  const dir = mkdtempSync(join(tmpdir(), 'apticks-coding-'));
  const opts = { cwd: dir, maxBuffer: 256 * 1024 * 1024, encoding: 'utf8' as const, stdio: ['ignore', 'pipe', 'pipe'] as ['ignore', 'pipe', 'pipe'] };
  const result = { c: new Map<number, string>(), cpp: new Map<number, string>(), java: new Map<number, string>(), python: new Map<number, string>() };
  try {
    for (let start = 0; start < qs.length; start += 400) {
      const batch = qs.slice(start, start + 400);
      writeFileSync(join(dir, 'q.c'), runnable(batch, 'c'));
      execFileSync('cc', ['-std=c11', '-O0', '-w', '-o', 'qc', 'q.c'], opts);
      for (const [k, x] of parseRun(execFileSync('./qc', [], opts))) result.c.set(k, x);

      writeFileSync(join(dir, 'q.cpp'), runnable(batch, 'cpp'));
      execFileSync('c++', ['-std=c++17', '-O0', '-w', '-o', 'qcpp', 'q.cpp'], opts);
      for (const [k, x] of parseRun(execFileSync('./qcpp', [], opts))) result.cpp.set(k, x);

      writeFileSync(join(dir, 'Main.java'), runnable(batch, 'java'));
      execFileSync('javac', ['-nowarn', 'Main.java'], opts);
      for (const [k, x] of parseRun(execFileSync('java', ['-Xss16m', 'Main'], opts))) result.java.set(k, x);

      writeFileSync(join(dir, 'q.py'), runnable(batch, 'python'));
      for (const [k, x] of parseRun(execFileSync('python3', ['q.py'], opts))) result.python.set(k, x);
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
  return result;
}

// ---------------------------------------------------------------------
// Wrong options: the same program with a typical slip
// ---------------------------------------------------------------------

function mapStmts(body: S[], f: (s: S) => S[] | null): S[] | null {
  // Applies f to the first statement it changes (depth-first); null if none.
  for (let i = 0; i < body.length; i++) {
    const s = body[i];
    const here = f(s);
    if (here) return [...body.slice(0, i), ...here, ...body.slice(i + 1)];
    for (const key of ['body', 'then', 'else'] as const) {
      const inner = (s as unknown as Record<string, unknown>)[key] as S[] | undefined;
      if (inner) {
        const changed = mapStmts(inner, f);
        if (changed) return [...body.slice(0, i), { ...s, [key]: changed } as S, ...body.slice(i + 1)];
      }
    }
  }
  return null;
}

function mapProg(p: Prog, f: (s: S) => S[] | null): Prog | null {
  const main = mapStmts(p.main, f);
  if (main) return { ...p, main };
  for (let i = 0; i < p.fns.length; i++) {
    const body = mapStmts(p.fns[i].body, f);
    if (body) return { ...p, fns: p.fns.map((x, j) => (j === i ? { ...x, body } : x)) };
  }
  return null;
}

const FLIP: Partial<Record<Op, Op>> = { '<': '<=', '<=': '<', '>': '>=', '>=': '>' };

function flipFirst(e: E): E | null {
  if (e.k !== 'b') return null;
  if (FLIP[e.op]) return { ...e, op: FLIP[e.op]! };
  const a = flipFirst(e.a);
  if (a) return { ...e, a };
  const c = flipFirst(e.b);
  return c ? { ...e, b: c } : null;
}

function slips(p: Prog): Prog[] {
  const all: (Prog | null)[] = [];
  // Every `for` (one at a time): runs once more, once fewer.
  for (const d of [1, -1]) {
    let k = 0;
    for (let target = 0; target < 3; target++) {
      k = 0;
      all.push(mapProg(p, (s) => (s.k === 'for' && k++ === target ? [{ ...s, to: { k: 'b', op: '+', a: s.to, b: n(d * Math.sign(s.step)) } }] : null)));
    }
  }
  // < and <= mixed up in a condition.
  for (let target = 0; target < 3; target++) {
    let k = 0;
    all.push(mapProg(p, (s) => {
      if ((s.k === 'if' || s.k === 'while') && k++ === target) {
        const c = flipFirst(s.c);
        return c ? [{ ...s, c }] : null;
      }
      return null;
    }));
  }
  // A forgotten break or continue.
  all.push(mapProg(p, (s) => (s.k === 'if' && s.then.length === 1 && (s.then[0].k === 'break' || s.then[0].k === 'continue') ? [] : null)));
  // `=` instead of `+=` (the total doesn't add up).
  all.push(mapProg(p, (s) => (s.k === 'aug' && (s.op === '+' || s.op === '*') ? [set(s.n, s.e)] : null)));
  // Starting from 1 instead of 0, or 0 instead of 1.
  all.push(mapProg(p, (s) => (s.k === 'let' && s.e.k === 'n' && (s.e.v === 0 || s.e.v === 1) ? [let_(s.n, 1 - s.e.v)] : null)));
  // Two steps of a loop body in the wrong order.
  all.push(mapProg(p, (s) => {
    if ((s.k === 'for' || s.k === 'while') && s.body.length >= 2) {
      const body = [...s.body];
      [body[0], body[1]] = [body[1], body[0]];
      return [{ ...s, body }];
    }
    return null;
  }));
  // A recursion's base case returning the other usual value.
  all.push(mapProg(p, (s) => (s.k === 'if' && s.then.length === 1 && s.then[0].k === 'ret' && s.then[0].e.k === 'n'
    ? [{ ...s, then: [ret((s.then[0].e as { v: number }).v === 0 ? 1 : 0)] }] : null)));
  return all.filter((x): x is Prog => x !== null);
}

// ---------------------------------------------------------------------
// Templates
// ---------------------------------------------------------------------

// Seeded so re-running produces the same bank.
function mulberry32(seed: number) {
  return () => {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rand = mulberry32(20261120);
const int = (lo: number, hi: number) => lo + Math.floor(rand() * (hi - lo + 1));
const pick = <T>(xs: readonly T[]): T => xs[Math.floor(rand() * xs.length)];
function shuffle<T>(xs: readonly T[]): T[] {
  const a = [...xs];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

type Difficulty = 1 | 2 | 3;
type Made = {
  topic: string;
  difficulty: Difficulty;
  prog: Prog;
  watch?: string; // a variable worth following pass by pass
  explain: (out: string, trace: number[]) => string;
  extra?: (out: string) => string[]; // more wrong options a template knows about
};

const flow = (name: string, trace: number[]) =>
  trace.length > 1 && trace.length <= 8 ? ` Pass by pass, ${name} is ${trace.join(' → ')}.` : '';

const TEMPLATES: { name: string; make: () => Made }[] = [
  {
    name: 'loop-sum',
    make: () => {
      const a = int(0, 3), to = a + int(2, 5), k = int(1, 4), s0 = pick([0, 0, 1, 5]);
      const body = k === 1 ? aug('s', '+', 'i') : aug('s', '+', b('i', '*', k));
      return {
        topic: 'Loops', difficulty: 1, watch: 's',
        prog: { fns: [], main: [let_('s', s0), for_('i', a, to, [body]), print('s')] },
        explain: (out, t) => `The loop runs for i = ${a} to ${to} (${to} included), adding ${k === 1 ? 'i' : `i × ${k}`} to s each time.${flow('s', t)} So it prints ${out}.`,
      };
    },
  },
  {
    name: 'loop-step',
    make: () => {
      const a = int(0, 6), st = int(2, 4), to = a + st * int(2, 4) + int(0, st - 1);
      return {
        topic: 'Loops', difficulty: 1,
        prog: { fns: [], main: [for_('i', a, to, [print('i')], st)] },
        explain: (out) => `i starts at ${a} and goes up by ${st} while it is at most ${to}, printing each value: ${out}.`,
      };
    },
  },
  {
    name: 'loop-countdown',
    make: () => {
      const a = int(8, 20), st = int(2, 4), to = int(0, 3);
      return {
        topic: 'Loops', difficulty: 1,
        prog: { fns: [], main: [for_('i', a, to, [print('i')], -st)] },
        explain: (out) => `i starts at ${a} and goes down by ${st} while it is at least ${to}: ${out}.`,
      };
    },
  },
  {
    name: 'nested-count',
    make: () => {
      const m = int(3, 6);
      const kind = pick(['j-from-i', 'j-to-i', 'j-below-i'] as const);
      const inner = kind === 'j-from-i' ? for_('j', 'i', m, [aug('c', '+', 1)])
        : kind === 'j-to-i' ? for_('j', 1, 'i', [aug('c', '+', 1)])
        : for_('j', 1, b('i', '-', 1), [aug('c', '+', 1)]);
      return {
        topic: 'Nested Loops', difficulty: 2, watch: 'c',
        prog: { fns: [], main: [let_('c', 0), for_('i', 1, m, [inner]), print('c')] },
        explain: (out, t) => `The inner loop runs ${kind === 'j-from-i' ? `${m} − i + 1` : kind === 'j-to-i' ? 'i' : 'i − 1'} times for each i from 1 to ${m}.${flow('c', t)} Total: ${out}.`,
      };
    },
  },
  {
    name: 'digit-sum',
    make: () => {
      const x = int(100, 9999);
      return {
        topic: 'While Loops', difficulty: 2, watch: 's',
        prog: { fns: [], main: [let_('x', x), let_('s', 0), while_(b('x', '>', 0), [aug('s', '+', b('x', '%', 10)), aug('x', '/', 10)]), print('s')] },
        explain: (out) => `x % 10 is the last digit and x / 10 drops it, so the loop adds up the digits of ${x}: ${String(x).split('').join(' + ')} = ${out}.`,
        extra: () => [String(x).split('').reverse().join(''), String(String(x).length)],
      };
    },
  },
  {
    name: 'reverse-number',
    make: () => {
      const x = int(102, 9876);
      return {
        topic: 'While Loops', difficulty: 2, watch: 'r',
        prog: { fns: [], main: [let_('x', x), let_('r', 0), while_(b('x', '>', 0), [set('r', b(b('r', '*', 10), '+', b('x', '%', 10))), aug('x', '/', 10)]), print('r')] },
        explain: (out, t) => `Each pass moves the last digit of x onto the end of r, so r becomes ${x} reversed.${flow('r', t)} A leading zero disappears, so it prints ${out}.`,
        extra: () => [String(x), String(x).split('').reverse().join('').padEnd(String(x).length, '0')],
      };
    },
  },
  {
    name: 'halving',
    make: () => {
      const x = int(20, 500);
      return {
        topic: 'While Loops', difficulty: 1, watch: 'x',
        prog: { fns: [], main: [let_('x', x), let_('c', 0), while_(b('x', '>', 1), [aug('x', '/', 2), aug('c', '+', 1)]), print('c')] },
        explain: (out, t) => `x is halved (integer division) until it reaches 1.${flow('x', t)} That takes ${out} steps.`,
      };
    },
  },
  {
    name: 'skip-multiples',
    make: () => {
      const m = int(6, 12), k = int(2, 4);
      return {
        topic: 'Loops', difficulty: 2, watch: 's',
        prog: { fns: [], main: [let_('s', 0), for_('i', 1, m, [if_(b(b('i', '%', k), '==', 0), [cont]), aug('s', '+', 'i')]), print('s')] },
        explain: (out) => `continue skips the rest of the loop whenever i is a multiple of ${k}, so s adds every number from 1 to ${m} except the multiples of ${k}: ${out}.`,
      };
    },
  },
  {
    name: 'break-total',
    make: () => {
      const limit = int(10, 40), k = int(1, 3);
      return {
        topic: 'Loops', difficulty: 2, watch: 's',
        prog: { fns: [], main: [let_('s', 0), let_('c', 0), for_('i', 1, 20, [aug('s', '+', b('i', '*', k)), aug('c', '+', 1), if_(b('s', '>', limit), [brk])]), print('c'), print('s')] },
        explain: (out, t) => `s grows by i × ${k} each pass and the loop stops (break) as soon as s passes ${limit}.${flow('s', t)} So c and s print as ${out}.`,
      };
    },
  },
  {
    name: 'div-mod',
    make: () => {
      const x = int(17, 99), y = int(3, 9);
      return {
        topic: 'Operators', difficulty: 1,
        prog: { fns: [], main: [let_('a', x), let_('b', y), print(b('a', '/', 'b')), print(b('a', '%', 'b'))] },
        explain: (out) => `With whole numbers, / drops the fraction and % gives the remainder: ${x} = ${Math.trunc(x / y)} × ${y} + ${x % y}. It prints ${out}.`,
        extra: () => [`${(x / y).toFixed(2).replace(/0+$/, '').replace(/\.$/, '')} ${x % y}`, `${x % y} ${Math.trunc(x / y)}`],
      };
    },
  },
  {
    name: 'precedence',
    make: () => {
      const [p, q, r, s, t] = [int(2, 9), int(2, 9), int(2, 6), int(10, 40), int(2, 5)];
      const e = b(b(p, '+', b(q, '*', r)), '-', b(s, '/', t));
      const leftToRight = Math.trunc(((p + q) * r - s) / t);
      return {
        topic: 'Operators', difficulty: 1,
        prog: { fns: [], main: [let_('x', e), print('x')] },
        explain: (out) => `* and / go before + and −, and ${s} / ${t} is ${Math.trunc(s / t)} with whole numbers: ${p} + ${q * r} − ${Math.trunc(s / t)} = ${out}.`,
        extra: () => [String(leftToRight), String(p + q * r - s / t).includes('.') ? (p + q * r - s / t).toFixed(1) : String(p + q * r - s / t + 1)],
      };
    },
  },
  {
    name: 'compound-assign',
    make: () => {
      const x = int(3, 12), d1 = int(2, 6), m = int(2, 4), d2 = int(1, 5);
      return {
        topic: 'Operators', difficulty: 1,
        prog: { fns: [], main: [let_('x', x), aug('x', '+', d1), aug('x', '*', m), aug('x', '-', d2), aug('x', '%', 7), print('x')] },
        explain: (out) => `Step by step: ${x} + ${d1} = ${x + d1}, × ${m} = ${(x + d1) * m}, − ${d2} = ${(x + d1) * m - d2}, then the remainder after dividing by 7 is ${out}.`,
        extra: () => [String((x + d1) * m - d2), String(x + d1 * m - d2)],
      };
    },
  },
  {
    name: 'bitwise',
    make: () => {
      const x = int(5, 30), y = int(3, 20);
      const [o1, o2] = shuffle(['&', '|', '^'] as const);
      const bits = (k: number) => k.toString(2);
      return {
        topic: 'Bitwise', difficulty: 2,
        prog: { fns: [], main: [let_('a', x), let_('b', y), print(b('a', o1, 'b')), print(b('a', o2, 'b'))] },
        explain: (out) => `In binary a = ${bits(x)} and b = ${bits(y)}. & keeps bits set in both, | keeps bits set in either, ^ keeps bits set in exactly one. It prints ${out}.`,
        extra: (out) => [`${x + y} ${Math.abs(x - y)}`, out.split(' ').reverse().join(' '), `${x & y} ${x | y} ${x ^ y}`.split(' ').slice(1).join(' ')],
      };
    },
  },
  {
    name: 'shifts',
    make: () => {
      const x = int(3, 40), k = int(1, 3), m = int(1, 3);
      return {
        topic: 'Bitwise', difficulty: 2,
        prog: { fns: [], main: [let_('a', x), print(b('a', '<<', k)), print(b('a', '>>', m))] },
        explain: (out) => `a << ${k} multiplies by 2^${k} (${x} × ${2 ** k}) and a >> ${m} divides by 2^${m}, dropping the fraction (${x} / ${2 ** m}). It prints ${out}.`,
        extra: () => [`${x * k} ${Math.trunc(x / (m + 1))}`, `${x >> m} ${x << k}`, `${x * 2 * k} ${x - m}`],
      };
    },
  },
  {
    name: 'swap-trick',
    make: () => {
      const x = int(3, 30), y = int(3, 30);
      return {
        topic: 'Variables', difficulty: 1,
        prog: { fns: [], main: [let_('a', x), let_('b', y), set('a', b('a', '+', 'b')), set('b', b('a', '-', 'b')), set('a', b('a', '-', 'b')), print('a'), print('b')] },
        explain: () => `a becomes ${x + y}, then b = ${x + y} − ${y} = ${x}, then a = ${x + y} − ${x} = ${y}. The three lines swap a and b without a third variable: it prints ${y} ${x}.`,
        extra: () => [`${x} ${y}`, `${x + y} ${x}`],
      };
    },
  },
  {
    name: 'running-update',
    make: () => {
      const x = int(1, 9), y = int(1, 9), times = int(3, 5);
      return {
        topic: 'Variables', difficulty: 2, watch: 'a',
        prog: { fns: [], main: [let_('a', x), let_('b', y), for_('i', 1, times, [set('a', b('a', '+', 'b')), set('b', b('a', '-', 'b'))]), print('a'), print('b')] },
        explain: (out, t) => `Each pass uses the new a straight away when it updates b.${flow('a', t)} After ${times} passes it prints ${out}.`,
      };
    },
  },
  {
    name: 'factorial-rec',
    make: () => {
      const k = int(3, 7), base = pick([1, 1, 2]);
      return {
        topic: 'Recursion', difficulty: 2,
        prog: { fns: [{ name: 'f', params: ['n'], body: [if_(b('n', '<=', base), [ret(base === 1 ? 1 : 2)]), ret(b('n', '*', call('f', b('n', '-', 1))))] }], main: [print(call('f', k))] },
        explain: (out) => `f(${k}) = ${k} × f(${k - 1}) and so on down to f(${base}) = ${base === 1 ? 1 : 2}. Multiplied back up, that is ${out}.`,
      };
    },
  },
  {
    name: 'sum-rec',
    make: () => {
      const k = int(4, 9), d = pick([1, 2]);
      return {
        topic: 'Recursion', difficulty: 2,
        prog: { fns: [{ name: 'f', params: ['n'], body: [if_(b('n', '<=', 0), [ret(0)]), ret(b('n', '+', call('f', b('n', '-', d))))] }], main: [print(call('f', k))] },
        explain: (out) => `f(n) adds n to f(n − ${d}) until n drops to 0 or below: ${Array.from({ length: Math.ceil(k / d) }, (_, i) => k - i * d).filter((x) => x > 0).join(' + ')} = ${out}.`,
      };
    },
  },
  {
    name: 'fib-rec',
    make: () => {
      const k = int(4, 9);
      return {
        topic: 'Recursion', difficulty: 3,
        prog: { fns: [{ name: 'f', params: ['n'], body: [if_(b('n', '<', 2), [ret('n')]), ret(b(call('f', b('n', '-', 1)), '+', call('f', b('n', '-', 2))))] }], main: [print(call('f', k))] },
        explain: (out) => `f is the Fibonacci sequence: f(0) = 0, f(1) = 1, and each value is the sum of the two before (0, 1, 1, 2, 3, 5, 8, 13, 21, 34). f(${k}) = ${out}.`,
      };
    },
  },
  {
    name: 'digits-rec',
    make: () => {
      const x = int(100, 9999);
      return {
        topic: 'Recursion', difficulty: 2,
        prog: { fns: [{ name: 'f', params: ['n'], body: [if_(b('n', '==', 0), [ret(0)]), ret(b(b('n', '%', 10), '+', call('f', b('n', '/', 10))))] }], main: [print(call('f', x))] },
        explain: (out) => `Each call takes the last digit (n % 10) and recurses on the rest (n / 10), so f adds the digits of ${x}: ${out}.`,
        extra: () => [String(String(x).length), String(x % 10)],
      };
    },
  },
  {
    name: 'nested-calls',
    make: () => {
      const m = int(2, 4), x = int(1, 6), y = int(1, 6), z = int(1, 6);
      return {
        topic: 'Functions', difficulty: 1,
        prog: { fns: [{ name: 'g', params: ['a', 'b'], body: [ret(b(b('a', '*', m), '+', 'b'))] }], main: [print(call('g', call('g', x, y), z))] },
        explain: () => `The inner call runs first: g(${x}, ${y}) = ${x} × ${m} + ${y} = ${x * m + y}. Then g(${x * m + y}, ${z}) = ${(x * m + y) * m + z}.`,
        extra: () => [String(x * m + y), String(x * m + y * m + z)],
      };
    },
  },
  {
    name: 'gcd-loop',
    make: () => {
      const g = int(2, 12), x = g * int(2, 12), y = g * int(2, 12);
      if (x === y) return TEMPLATES.find((t) => t.name === 'gcd-loop')!.make();
      return {
        topic: 'Number Logic', difficulty: 2, watch: 'b',
        prog: { fns: [], main: [let_('a', x), let_('b', y), while_(b('b', '!=', 0), [let_('t', 'b'), set('b', b('a', '%', 'b')), set('a', 't')]), print('a')] },
        explain: (out) => `This is Euclid's algorithm: replace (a, b) with (b, a % b) until b is 0. What's left in a is the HCF of ${x} and ${y}: ${out}.`,
        extra: () => [String((x * y) / Number(gcdOf(x, y))), String(Math.min(x, y))],
      };
    },
  },
  {
    name: 'array-even-sum',
    make: () => {
      const vals = Array.from({ length: int(5, 6) }, () => int(1, 20));
      return {
        topic: 'Arrays', difficulty: 1,
        prog: { fns: [], main: [arr('a', vals), let_('s', 0), for_('i', 0, vals.length - 1, [if_(b(b(at('a', 'i'), '%', 2), '==', 0), [aug('s', '+', at('a', 'i'))])]), print('s')] },
        explain: (out) => `The loop adds only the even values (a[i] % 2 == 0): ${vals.filter((x) => x % 2 === 0).join(' + ') || 'none'} = ${out}.`,
        extra: () => [String(vals.filter((_, i) => i % 2 === 0).reduce((s, x) => s + x, 0)), String(vals.reduce((s, x) => s + x, 0))],
      };
    },
  },
  {
    name: 'array-max',
    make: () => {
      const vals = shuffle(Array.from({ length: 6 }, () => int(1, 50)));
      return {
        topic: 'Arrays', difficulty: 2,
        prog: { fns: [], main: [arr('a', vals), let_('m', at('a', 0)), let_('p', 0), for_('i', 1, vals.length - 1, [if_(b(at('a', 'i'), '>', 'm'), [set('m', at('a', 'i')), set('p', 'i')])]), print('m'), print('p')] },
        explain: (out) => `m keeps the largest value seen so far and p its index (counting from 0). It prints the maximum and where it first appears: ${out}.`,
        extra: (out) => {
          const [m, p] = out.split(' ').map(Number);
          return [`${m} ${p + 1}`, `${Math.min(...vals)} ${vals.indexOf(Math.min(...vals))}`];
        },
      };
    },
  },
  {
    name: 'prefix-sums',
    make: () => {
      const vals = Array.from({ length: 5 }, () => int(1, 9)), k = int(1, 3);
      return {
        topic: 'Arrays', difficulty: 3,
        prog: { fns: [], main: [arr('a', vals), for_('i', 1, vals.length - 1, [setAt('a', 'i', b(at('a', 'i'), '+', at('a', b('i', '-', 1))))]), print(at('a', k)), print(at('a', 4))] },
        explain: (out) => `Each a[i] adds the already-updated a[i − 1], so a[i] becomes the total of everything up to i (a running sum). a[${k}] and a[4] print as ${out}.`,
        extra: () => [`${vals[k] + vals[k - 1]} ${vals[4] + vals[3]}`, `${vals[k]} ${vals[4]}`],
      };
    },
  },
  {
    name: 'array-reverse',
    make: () => {
      const vals = Array.from({ length: 6 }, () => int(1, 30)), k = int(0, 2), m = int(3, 5);
      return {
        topic: 'Arrays', difficulty: 2,
        prog: { fns: [], main: [arr('a', vals), let_('n', 6), for_('i', 0, b(b('n', '/', 2), '-', 1), [let_('t', at('a', 'i')), setAt('a', 'i', at('a', b(b('n', '-', 1), '-', 'i'))), setAt('a', b(b('n', '-', 1), '-', 'i'), 't')]), print(at('a', k)), print(at('a', m))] },
        explain: (out) => `The loop swaps a[i] with a[n − 1 − i] for the first half, which reverses the array: ${[...vals].reverse().join(', ')}. So a[${k}] and a[${m}] are ${out}.`,
        extra: () => [`${vals[k]} ${vals[m]}`],
      };
    },
  },
  {
    name: 'if-chain',
    make: () => {
      const hi = int(60, 80), mid = int(35, 55), x = pick([int(hi - 3, hi + 3), int(mid - 3, mid + 3), int(10, 30)]);
      return {
        topic: 'Conditions', difficulty: 1,
        prog: { fns: [], main: [let_('x', x), if_(b('x', '>=', hi), [print(3)], [if_(b('x', '>=', mid), [print(2)], [print(1)])])] },
        explain: (out) => `Only the first true branch runs. x = ${x}: ${x >= hi ? `${x} ≥ ${hi}` : x >= mid ? `${x} < ${hi} but ${x} ≥ ${mid}` : `${x} is below ${mid}`}, so it prints ${out}.`,
        extra: () => ['3 2 1', '0'],
      };
    },
  },
  {
    name: 'and-or',
    make: () => {
      const [x, y, z] = [int(1, 20), int(1, 20), int(1, 20)];
      return {
        topic: 'Conditions', difficulty: 2,
        prog: { fns: [], main: [let_('a', x), let_('b', y), let_('c', z), if_(b(b('a', '>', 'b'), '&&', b('b', '>', 'c')), [print(1)], [if_(b(b('a', '>', 'b'), '||', b('c', '>', 'b')), [print(2)], [print(3)])])] },
        explain: (out) => `a = ${x}, b = ${y}, c = ${z}. && needs both sides true, || needs at least one. ${x > y && y > z ? 'a > b and b > c are both true' : x > y || z > y ? 'The first test fails, but one side of the second is true' : 'Neither test passes'}, so it prints ${out}.`,
        extra: () => ['1 2', '0'],
      };
    },
  },
  {
    name: 'fib-loop',
    make: () => {
      const k = int(4, 10);
      return {
        topic: 'Loops', difficulty: 2, watch: 'a',
        prog: { fns: [], main: [let_('a', 0), let_('b', 1), for_('i', 1, k, [let_('t', b('a', '+', 'b')), set('a', 'b'), set('b', 't')]), print('a')] },
        explain: (out, t) => `a and b walk along the Fibonacci numbers one step per pass.${flow('a', t)} After ${k} passes a is ${out}.`,
      };
    },
  },
  {
    name: 'collatz',
    make: () => {
      const x = int(5, 30);
      return {
        topic: 'While Loops', difficulty: 3, watch: 'x',
        prog: { fns: [], main: [let_('x', x), let_('c', 0), while_(b('x', '!=', 1), [if_(b(b('x', '%', 2), '==', 0), [aug('x', '/', 2)], [set('x', b(b(3, '*', 'x'), '+', 1))]), aug('c', '+', 1)]), print('c')] },
        explain: (out, t) => `Even numbers are halved, odd ones become 3x + 1, until x reaches 1.${t.length <= 12 ? ` The path from ${x}: ${[x, ...t].join(' → ')}.` : ''} That's ${out} steps.`,
      };
    },
  },
  {
    name: 'count-primes',
    make: () => {
      const m = int(10, 30);
      return {
        topic: 'Nested Loops', difficulty: 3,
        prog: { fns: [], main: [let_('c', 0), for_('i', 2, m, [let_('p', 1), for_('j', 2, b('i', '-', 1), [if_(b(b('i', '%', 'j'), '==', 0), [set('p', 0), brk])]), if_(b('p', '==', 1), [aug('c', '+', 1)])]), print('c')] },
        explain: (out) => `p stays 1 only when nothing from 2 to i − 1 divides i, so c counts the primes from 2 to ${m}: ${primesTo(m).join(', ')}. That's ${out}.`,
      };
    },
  },
  {
    name: 'multiples-or',
    make: () => {
      const m = int(10, 20), [x, y] = shuffle([2, 3, 4, 5]).slice(0, 2);
      return {
        topic: 'Conditions', difficulty: 2, watch: 's',
        prog: { fns: [], main: [let_('s', 0), for_('i', 1, m, [if_(b(b(b('i', '%', x), '==', 0), '||', b(b('i', '%', y), '==', 0)), [aug('s', '+', 1)])]), print('s')] },
        explain: (out) => `s counts the numbers from 1 to ${m} divisible by ${x} or by ${y} (a number divisible by both counts once): ${out}.`,
        extra: () => [String(Math.floor(m / x) + Math.floor(m / y))],
      };
    },
  },
  {
    name: 'two-pointers',
    make: () => {
      const j0 = int(15, 40), da = int(1, 3), db = int(1, 4);
      return {
        topic: 'While Loops', difficulty: 2,
        prog: { fns: [], main: [let_('i', 0), let_('j', j0), let_('c', 0), while_(b('i', '<', 'j'), [aug('i', '+', da), aug('j', '-', db), aug('c', '+', 1)]), print('c'), print('i')] },
        explain: (out) => `i climbs by ${da} and j falls by ${db} each pass, so the gap of ${j0} closes by ${da + db} per pass until i is no longer below j. It prints ${out}.`,
      };
    },
  },
  {
    name: 'power-mod',
    make: () => {
      const base = int(2, 5), k = int(3, 6), m = int(7, 13);
      return {
        topic: 'Number Logic', difficulty: 2, watch: 'p',
        prog: { fns: [], main: [let_('p', 1), for_('i', 1, k, [set('p', b(b('p', '*', base), '%', m))]), print('p')] },
        explain: (out, t) => `p is multiplied by ${base} and reduced mod ${m} each pass, so it ends as ${base}^${k} mod ${m}.${flow('p', t)} It prints ${out}.`,
        extra: () => [String(base ** k), String((base * k) % m)],
      };
    },
  },
];

function gcdOf(a: number, b: number): number {
  return b === 0 ? a : gcdOf(b, a % b);
}
function primesTo(m: number) {
  return Array.from({ length: m - 1 }, (_, i) => i + 2).filter((x) => Array.from({ length: x - 2 }, (_, i) => i + 2).every((d) => x % d !== 0));
}

// ---------------------------------------------------------------------
// Building the bank
// ---------------------------------------------------------------------

const TIME: Record<Difficulty, number> = { 1: 40, 2: 50, 3: 60 };
const PER_TEMPLATE = 140;
const MAX_LINES = 16;
const MAX_WIDTH = 46;

type Built = Made & { template: string; out: string; options: string[]; correctIdx: number; explanation: string; code: Record<Lang, string> };

function options(out: string, wrong: string[]): string[] | null {
  const seen = new Set([out]);
  const good: string[] = [];
  for (const w of wrong) {
    const t = w.trim();
    if (!t || seen.has(t) || t.length > 24 || /NaN|undefined|Infinity/.test(t)) continue;
    seen.add(t);
    good.push(t);
  }
  // Filler: the answer's numbers nudged, the way a tired reader slips.
  for (const d of [1, -1, 2, 10, -2]) {
    if (good.length >= 3) break;
    const parts = out.split(' ').map(Number);
    const last = parts.length - 1;
    const t = parts.map((x, i) => (i === last ? x + d : x)).join(' ');
    if (!seen.has(t) && !t.includes('-')) {
      seen.add(t);
      good.push(t);
    }
  }
  if (good.length < 3) return null;
  return shuffle([out, ...good.slice(0, 3)]);
}

const built: Built[] = [];
const seenCode = new Set<string>();
for (const t of TEMPLATES) {
  let made = 0;
  for (let tries = 0; tries < PER_TEMPLATE * 30 && made < PER_TEMPLATE; tries++) {
    const m = t.make();
    const res = evaluate(m.prog, m.watch);
    if (!res || res.out.length > 24) continue;
    const code = Object.fromEntries(LANGS.map((l) => [l, display(m.prog, l)])) as Record<Lang, string>;
    if (seenCode.has(code.python)) continue;
    const tooBig = LANGS.some((l) => {
      const ls = code[l].split('\n');
      return ls.length > MAX_LINES || ls.some((x) => x.length > MAX_WIDTH);
    });
    if (tooBig) continue;
    // Slips first (they are real mistakes), then what the template knows.
    const wrong = [
      ...shuffle(slips(m.prog).map((p) => evaluate(p)?.out).filter((x): x is string => !!x)),
      ...(m.extra?.(res.out) ?? []),
    ];
    const opts = options(res.out, wrong);
    if (!opts) continue;
    seenCode.add(code.python);
    built.push({
      ...m, template: t.name, out: res.out, options: opts, correctIdx: opts.indexOf(res.out),
      explanation: m.explain(res.out, res.trace), code,
    });
    made++;
  }
}

// Run every program for real; keep only questions all four languages agree on.
const runs = runAll(built.map((q, id) => ({ id, prog: q.prog })));
const kept: Built[] = [];
const dropped: Record<string, number> = {};
built.forEach((q, id) => {
  const agree = (['c', 'cpp', 'java', 'python'] as const).every((l) => runs[l].get(id) === q.out);
  if (agree) kept.push(q);
  else dropped[q.template] = (dropped[q.template] ?? 0) + 1;
});

const sq = (s: string | null) => (s === null ? 'null' : `'${s.replace(/'/g, "''")}'`);
const sqArr = (xs: string[]) => `array[${xs.map(sq).join(', ')}]`;
const BODY = 'What does this code print?';
const rows = kept.map((q) => {
  const variant = createHash('md5').update(q.code.c + '|' + q.code.python).digest('hex').slice(0, 16);
  return `  ('coding', ${sq(q.topic)}, ${q.difficulty}, ${sq(BODY)}, ${sqArr(q.options)}, ${q.correctIdx}, ${sq(q.explanation)}, ${TIME[q.difficulty]}, ${sq('coding-' + q.template)}, ${sq(variant)}, ${sq(JSON.stringify(q.code))}::jsonb)`;
});

// In parts of about 1,000, so each fits in one paste into the SQL editor.
const PART = 1000;
const parts = Math.ceil(rows.length / PART);
const oldFile = new URL('../supabase/seed-coding.sql', import.meta.url);
rmSync(oldFile, { force: true });
for (let i = 0; i < parts; i++) {
  const sql = `-- Generated by scripts/generate-coding.ts. Do not edit by hand.
-- Part ${i + 1} of ${parts}. Needs migration 0022_subjects. Safe to run again: existing rows are kept.
-- Every answer here is what real gcc/clang, g++, javac and python3 printed.

insert into public.questions
  (section, topic, difficulty, body, options, correct_idx, explanation, time_limit_s, template, variant, code)
values
${rows.slice(i * PART, (i + 1) * PART).join(',\n')}
on conflict (body, (coalesce(variant, ''))) do nothing;
`;
  writeFileSync(new URL(`../supabase/seed-coding-${i + 1}.sql`, import.meta.url), sql);
}

const byTopic = kept.reduce<Record<string, number>>((acc, q) => ((acc[q.topic] = (acc[q.topic] ?? 0) + 1), acc), {});
console.log(`Wrote ${kept.length} coding questions to supabase/seed-coding-1..${parts}.sql`);
console.log('By topic:', Object.entries(byTopic).map(([k, x]) => `${k} ${x}`).join(', '));
if (Object.keys(dropped).length) console.log('Dropped (languages disagreed):', dropped);
