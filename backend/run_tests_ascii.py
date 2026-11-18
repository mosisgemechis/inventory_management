"""
ASCII-safe wrapper that runs test_sync_integrity.py and captures
pass/fail per test using importlib, then prints clean ASCII results.
"""
import sys, importlib, traceback, io, os

# Redirect stdout to capture all print() output from test functions
# and replace any non-ASCII with '?'
def _safe(s):
    return s.encode('ascii', errors='replace').decode('ascii')

# Suppress noisy startup prints by routing them to /dev/null during import
import contextlib
with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
    import test_sync_integrity as T

tests = [
    T.test_1_user_id_name_error_fixed,
    T.test_2_sale_rejected_when_insufficient_stock,
    T.test_3_online_offline_product_dedup,
    T.test_4_both_offline_product_dedup,
    T.test_5_different_barcodes_not_merged,
    T.test_6_batch_references_relinked_after_dedup,
    T.test_7_offline_sale_correct_stock_after_sync,
    T.test_8_idempotent_sale_retry_no_double_deduction,
    T.test_9_concurrent_sales_no_negative_stock,
    T.test_10_oversell_299_then_offline_10,
    T.test_11_simultaneous_sales_exceed_stock,
    T.test_12_out_of_order_sale_no_fake_product,
    T.test_13_technical_error_rejection_classified_correctly,
    T.test_14_conflict_notifications_idempotent,
    T.test_15_apply_entity_mutation_signature,
    T.test_16_sale_conflict_message_is_human_readable,
    T.test_17_three_device_convergence,
    T.test_18_product_identity_resolution_is_durable,
    T.test_19_cross_business_same_name_never_merged,
    T.test_20_sale_allocation_deducts_once_from_branch_stock_and_batch,
]

passed = []
failed = []
results = open('test_report.txt', 'w', encoding='ascii', errors='replace')

for t in tests:
    name = t.__name__
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            t()
        out = _safe(buf.getvalue().strip())
        line = f"[PASS] {name}"
        passed.append(name)
    except Exception as e:
        tb = traceback.format_exc()
        first_line = _safe(str(e).splitlines()[0][:120]) if str(e) else ''
        line = f"[FAIL] {name}: {first_line}"
        failed.append((name, _safe(tb)))

    print(line)
    results.write(line + '\n')

print('')
print(f"Results: {len(passed)}/{len(tests)} passed, {len(failed)} failed")
results.write(f"\nResults: {len(passed)}/{len(tests)} passed, {len(failed)} failed\n")

if failed:
    print('\n--- FAILURES ---')
    results.write('\n--- FAILURES ---\n')
    for name, tb in failed:
        print(f"\n{name}:")
        results.write(f"\n{name}:\n")
        for ln in tb.splitlines()[-10:]:
            safe_ln = _safe(ln)
            print(f"  {safe_ln}")
            results.write(f"  {safe_ln}\n")

results.close()
print('\nFull report written to test_report.txt')
sys.exit(1 if failed else 0)
