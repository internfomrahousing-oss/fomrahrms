import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { findAppUserByLoginIdentifier } from "./index.ts";

class FakeQuery {
  constructor(
    private readonly rows: Array<Record<string, unknown>>,
    private readonly column: string,
    private readonly value: string,
  ) {}

  maybeSingle() {
    const match = this.rows.find((row) => {
      const candidate = String(row[this.column] ?? "").trim();
      return candidate.toLowerCase() === this.value.toLowerCase();
    });

    return Promise.resolve({ data: match ?? null, error: null });
  }
}

class FakeSupabase {
  constructor(private readonly rows: Array<Record<string, unknown>>) {}

  from(_table: string) {
    return {
      select(_columns: string) {
        return {
          ilike(column: string, value: string) {
            return new FakeQuery(this.rows, column, value);
          },
        };
      },
    };
  }
}

Deno.test("findAppUserByLoginIdentifier falls back to company email", async () => {
  const rows = [{
    email: "john.smith@fomrahousing.in",
    company_email: "john.smith@company.com",
    employee_id: "EMP1001",
  }];
  const result = await findAppUserByLoginIdentifier(new FakeSupabase(rows) as never, "john.smith@company.com");

  assertEquals(result.matchedField, "company_email");
  assertEquals(result.row?.employee_id, "EMP1001");
});

Deno.test("findAppUserByLoginIdentifier accepts employee id", async () => {
  const rows = [{
    email: "jane.doe@fomrahousing.in",
    company_email: "",
    employee_id: "EMP2002",
  }];
  const result = await findAppUserByLoginIdentifier(new FakeSupabase(rows) as never, "EMP2002");

  assertEquals(result.matchedField, "employee_id");
  assertEquals(result.row?.email, "jane.doe@fomrahousing.in");
});
