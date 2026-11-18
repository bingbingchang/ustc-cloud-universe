import asyncio
import unittest
from call_budget import CallBudget,ModelRateLimitError

class BudgetTests(unittest.IsolatedAsyncioTestCase):
    async def test_shared_window_and_expiry(self):
        now=[0.0];budget=CallBudget(2,2,clock=lambda:now[0])
        async with budget.call():pass
        async with budget.call():pass
        with self.assertRaises(ModelRateLimitError) as error:
            async with budget.call():pass
        self.assertEqual(error.exception.retry_after,60)
        now[0]=60
        async with budget.call():pass

    async def test_concurrency_rejects_and_cancellation_releases(self):
        budget=CallBudget(1,10);entered=asyncio.Event()
        async def hold():
            async with budget.call():entered.set();await asyncio.Event().wait()
        task=asyncio.create_task(hold());await entered.wait()
        with self.assertRaises(ModelRateLimitError):
            async with budget.call():pass
        task.cancel()
        with self.assertRaises(asyncio.CancelledError):await task
        self.assertEqual(budget.active,0)
        async with budget.call():pass

if __name__=='__main__':unittest.main()
