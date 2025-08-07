# Project Gamma - Domain and Business Rules

This document describes the domain, user profiles, core entities, and business rules of the Logistics System.

## User Roles

- **`ADMIN`**: Full access to the system, including management of users, warehouses, trucks, routes, and general settings.
- **`DISPATCHER`**: Responsible for creating shipments, planning dispatches, and allocating packages to routes.
- **`DRIVER`**: Can view shipments associated with their routes and update the status of these shipments during transport.

---

## Core Entities

- **User**: Authenticated users in the system, with associated roles that define their access and permission levels.
- **Warehouse**: Represents the physical warehouses of origin and destination for shipments.
- **Truck**: Vehicle used for transport, with attributes such as license plate, maximum load capacity, and status (e.g., `AVAILABLE`, `UNDER_MAINTENANCE`, `INACTIVE`).
- **Route**: A logical route planned between an origin and a destination warehouse, with a specific truck assigned and a status (e.g., `ACTIVE`, `INACTIVE`).
- **MapRoute**: Geographic details of a `Route`, containing real coordinates, estimated distance, and travel time, obtained through a maps API.
- **Shipment**: Represents a shipment, which is a collection of packages to be transported from an origin to a destination. It has a status (e.g., `PENDING_VALIDATION`, `AWAITING_DISPATCH`, `IN_TRANSIT`, `DELIVERED`, `CANCELLED`, `VALIDATION_FAILED`, `DELIVERY_FAILED`) and a `freightCost`.
- **Package**: Individual packages that make up a shipment, each with a description, weight, and unique identifier. It may have an inventory status (e.g., `IN_WAREHOUSE`, `ALLOCATED_TO_SHIPMENT`, `IN_TRANSIT`).
- **ShipmentStatusHistory**: A chronological record of all status changes for a shipment, including who made the change and when.
- **EventMessage**: A standard structure for messages exchanged asynchronously via event queues (e.g., for auditing, notifications, task processing).
- **Notification**: A record of notifications sent to system users.

---

## Business Rules

### Rule #001 - Shipment Creation

**Objective:** Allow `DISPATCHER` or `ADMIN` users to register a new shipment with packages assigned to a route.

**Rules:**

1.  Only users with the `DISPATCHER` or `ADMIN` profile can create shipments.
2.  A shipment must contain at least one package.
3.  The total weight of the shipment's packages cannot exceed the maximum load capacity of the `Truck` assigned to the `Route`.
4.  The selected route must:
    - Be previously registered and have an `ACTIVE` status.
    - Have an assigned truck with an `AVAILABLE` status.
5.  The initial status of the shipment must be `PENDING_VALIDATION`.
6.  Each `Package` in the shipment must contain:
    - A clear textual description of its contents.
    - Weight in kilograms (must be > 0 kg).
    - A unique identifier for the package.
7.  Creating a shipment triggers an event (e.g., `SHIPMENT_CREATION_REQUESTED`) to a queue. This event will trigger an asynchronous validation (see Rule #009) to confirm the allocation to the route.

---

### Rule #002 - Shipment Tracking

**Objective:** Allow querying the current status and history of a shipment using a tracking code.

**Rules:**

1.  The tracking code must be unique, secure, and automatically generated for each shipment.
2.  The tracking query can be public (accessible without authentication) or restricted to authenticated users, depending on system configuration.
3.  The query response must include:
    - The current status of the shipment (e.g., `AWAITING_DISPATCH`, `IN_TRANSIT`, `DELIVERED`).
    - The complete status history (`ShipmentStatusHistory`), with the timestamp of each change and, if applicable, the user or system responsible.
    - Basic shipment information (e.g., origin, destination, estimated delivery date if applicable).
4.  If public access is enabled, an additional security layer (e.g., rate limiting by IP) should be considered.

---

### Rule #003 - Shipment Status Update

**Objective:** Allow `DRIVER`s to update the shipment status as it progresses along the delivery route.

**Rules:**

1.  Only the `DRIVER` currently assigned to the shipment's route can update its status.
2.  The valid statuses and their transitions must be clearly defined. Example flow:
    - `AWAITING_DISPATCH` -> `IN_TRANSIT`
    - `AWAITING_DISPATCH` -> `CANCELLED`
    - `IN_TRANSIT` -> `DELIVERED`
    - `IN_TRANSIT` -> `DELIVERY_FAILED` (with a mandatory reason)
    - `IN_TRANSIT` -> `CANCELLED` (e.g., in case of major issues on the route, with justification)
    - `DELIVERY_FAILED` -> `IN_TRANSIT` (for a new attempt, if applicable)
    - `DELIVERY_FAILED` -> `AWAITING_RETURN` (if it is to be returned to the sender/warehouse)
    - `DELIVERED` (final state)
    - `CANCELLED` (final state)
3.  Each status change must be recorded in the `ShipmentStatusHistory` entity.
4.  Skipping mandatory steps in the status flow is not allowed without specific justification or permission.
5.  Status updates trigger events (e.g., `SHIPMENT_STATUS_UPDATED`) to a queue, which can be consumed for auditing and notifications.

---

### Rule #004 - Route Planning

**Objective:** Allow `ADMIN` or `DISPATCHER` users to create and manage logical routes available for dispatching shipments.

**Rules:**

1.  A `Route` must contain:
    - An origin `Warehouse`.
    - A destination `Warehouse`.
    - A `Truck` assigned to carry out the transport on this route.
    - A status (e.g., `ACTIVE`, `INACTIVE`).
2.  A `Truck` with `AVAILABLE` status can only be assigned to one `ACTIVE` route at a time.
3.  The total load capacity of the route is determined by the capacity of the associated truck. The system should help control the route's occupancy.
4.  A logical `Route` must be linked to a geographic `MapRoute` containing the journey details.

---

### Rule #005 - Warehouse Management

**Objective:** Allow for the creation and maintenance of the warehouse infrastructure.

**Rules:**

1.  Only users with the `ADMIN` profile can register, edit, or remove warehouses.
2.  A `Warehouse` must have at least:
    - A name or identification.
    - A full address (including city and state/province).
    - A unique identifier code.

---

### Rule #006 - User Management

**Objective:** Allow for the creation and access control management of different user profiles in the system.

**Rules:**

1.  Only users with the `ADMIN` profile can register new users.
2.  Each `User` must be associated with one of the defined profiles (`ADMIN`, `DISPATCHER`, `DRIVER`).
3.  Login will be performed via a specific endpoint (`/auth/login`) which, upon success, will return a JSON Web Token (JWT).
4.  The JWT will have a defined expiration time and must be sent in the `Authorization` header (as a Bearer token) in subsequent requests to protected endpoints.

---

### Rule #007 - Action Auditing

**Objective:** To log sensitive and important actions performed in the system for traceability and security purposes.

**Rules:**

1.  The following actions (audit event types) must be audited:
    - `SHIPMENT_CREATED`, `SHIPMENT_UPDATED`, `SHIPMENT_CANCELLED`
    - `SHIPMENT_STATUS_CHANGED` (detailing from/to statuses)
    - `USER_LOGIN_SUCCESS`, `USER_LOGIN_FAILED`
    - `USER_CREATED`, `USER_UPDATED`, `USER_ROLE_CHANGED`
    - `ROUTE_CREATED`, `ROUTE_UPDATED`, `ROUTE_DELETED`
    - `TRUCK_CREATED`, `TRUCK_UPDATED`, `TRUCK_STATUS_CHANGED`
    - `WAREHOUSE_CREATED`, `WAREHOUSE_UPDATED`, `WAREHOUSE_DELETED`
2.  Audit logs must contain, at a minimum:
    - The ID of the user who performed the action (or "system" for automated actions).
    - The exact timestamp of the occurrence.
    - The type of action performed (as listed above).
    - Relevant data from the operation (e.g., ID of the affected entity, old and new values if applicable).
3.  Auditing must be performed asynchronously by sending an `EventMessage` to a dedicated queue.

---

### Rule #008 - Geographic Route Generation

**Objective:** To automatically generate the geographic route (`MapRoute`) based on the coordinates of the origin and destination warehouses of a logical `Route`, using an external maps API.

**Rules:**

1.  The geographic `MapRoute` is automatically generated (or retrieved from cache) when a logical `Route` is created or when its origin/destination warehouses are changed.
2.  The address information of the warehouses is converted into geographic coordinates for the maps API query.
3.  The response from the external maps API must provide at least: a list of coordinates, estimated distance, and estimated travel time.
4.  A failure in generating the `MapRoute` may mark the `Route` as `INACTIVE` or with a `PENDING_GEOROUTE` status and notify the `ADMIN`.

---

### Rule #009 - Asynchronous Task Processing with Queues

**Objective:** To use message queues to process tasks asynchronously, improving the system's responsiveness, scalability, and resilience.

**Rules:**

1.  The creation of a shipment (Rule #001.7) triggers a `SHIPMENT_CREATION_REQUESTED` event to a queue.
2.  A worker (queue consumer) will process this event to:
    - Validate the truck's capacity on the route (considering concurrency and the weight/volume of other shipments already allocated to the same trip/route).
    - Verify the availability and status of the route and truck.
    - Update the shipment status to `AWAITING_DISPATCH` (if validation is OK) or to `VALIDATION_FAILED` (with a reason) and trigger a notification (Rule #010).
3.  Shipment status updates (Rule #003.5) trigger a `SHIPMENT_STATUS_UPDATED` event for auditing and notification processing.
4.  Failures in message processing by consumers should be handled with a retry strategy and a Dead Letter Queue (DLQ).
5.  Auditing (Rule #007.3) and notification sending (Rule #010) should also be processed via events and queues.

---

### Rule #010 - System Notifications

**Objective:** To proactively keep users informed about relevant and critical events in the system.

**Rules:**

1.  The system must generate notifications for the following events and recipients:
    - **`DISPATCHER` / `ADMIN`**:
      - Shipment validation failure (`SHIPMENT_VALIDATION_FAILED`).
      - Shipment marked as `DELIVERY_FAILED`.
      - `MapRoute` generation failure.
    - **`DRIVER`**:
      - New shipment allocated to their active route.
      - Significant changes to their assigned routes.
    - **`ADMIN`**:
      - Messages accumulating in the DLQ.
      - Critical system errors.
    - **(Optional) End Customer**:
      - Shipment `IN_TRANSIT` (with tracking code).
      - Shipment `DELIVERED`.
      - Shipment `DELIVERY_FAILED` (with instructions).
2.  Notifications can be delivered through different configurable channels (e.g., email, internal system dashboard).
3.  The notification content must be clear, concise, and include relevant links or information for the required action.
4.  Users should be able to manage their notification preferences (if applicable).
5.  The sending of notifications must be asynchronous, using queues.

---

### Rule #011 - Delivery Failure and Returns Management

**Objective:** To define the process for handling shipments that could not be delivered to the final recipient.

**Rules:**

1.  A `DRIVER` can update a shipment's status to `DELIVERY_FAILED`, and must provide a standardized reason (e.g., `RECIPIENT_ABSENT`, `ADDRESS_INCORRECT`, `GOODS_DAMAGED`, `RECIPIENT_REFUSED`).
2.  A shipment with `DELIVERY_FAILED` status must:
    - Log the reason and the delivery attempt.
    - Trigger a notification to the `DISPATCHER` or `ADMIN` for follow-up.
3.  The system must allow for logging multiple delivery attempts for the same shipment, if applicable.
4.  After a limited number of unsuccessful delivery attempts, or by a `DISPATCHER`'s decision, the shipment may be directed to:
    - Return to the origin warehouse (status `AWAITING_RETURN` or `RETURNING_TO_ORIGIN`).
    - Be rerouted to a new address (if applicable, generating a new transport leg).
    - Be disposed of or handled otherwise, according to specific client business rules.
5.  The return flow must also have its statuses tracked (e.g., `RETURNED_TO_WAREHOUSE`).

---

### Rule #012 - Truck Management and Maintenance

**Objective:** To track and manage the status and maintenance of trucks to ensure their operational availability and safety.

**Rules:**

1.  Only users with the `ADMIN` profile can register, edit, or remove trucks (`Truck`).
2.  In addition to basic fields (license plate, capacity), a `Truck` must have:
    - An operational status: `AVAILABLE`, `UNDER_MAINTENANCE`, `INACTIVE`.
    - (Optional) Date of last maintenance, next scheduled maintenance.
3.  Only trucks with `AVAILABLE` status can be assigned to new `ACTIVE` routes.
4.  When changing a truck's status to `UNDER_MAINTENANCE` or `INACTIVE`:
    - If the truck is assigned to an `ACTIVE` route with `AWAITING_DISPATCH` or `PENDING_VALIDATION` shipments, the `ADMIN`/`DISPATCHER` must be notified to reassign the shipments/route to another truck.
    - Routes that exclusively depended on this truck may need to be temporarily deactivated.

---

### Rule #013 - Freight Cost Calculation

**Objective:** To automatically calculate the freight cost for a shipment at the time of its creation or planning.

**Rules:**

1.  The freight cost calculation should be triggered during the creation of a `Shipment`.
2.  The calculation logic must be encapsulated in a **Domain Service** (e.g., `FreightCalculatorService`) to ensure the complex rule does not overload the `Shipment` entity.
3.  The calculation must consider multiple factors, such as:
    - **Weight and Dimensions:** Actual weight or dimensional weight (whichever is greater).
    - **Distance:** Based on the distance calculated in the associated `MapRoute`.
    - **Service Type:** Different price tables for services (e.g., `STANDARD`, `EXPRESS`, `URGENT`).
    - **Additional Factors:** Configurable fees like fuel surcharges, remote area surcharges, and cargo insurance.
4.  The result of the calculation should be a `Money` **Value Object**, containing an amount and a currency, to avoid inaccuracies with float types.
5.  The calculated cost (`freightCost`) must be stored on the `Shipment` entity for future reference and billing.

---

### Rule #014 - Shipment Consolidation on Routes

**Objective:** To optimize the use of truck capacity by allowing a single trip/route to contain multiple shipments.

**Rules:**

1.  The system should treat an active `Route` as a "trip" or "manifest" for a truck, which can be loaded with multiple shipments.
2.  A `DISPATCHER` can allocate different `Shipment`s to the same active route instance.
3.  With each allocation attempt, the system must validate if the remaining capacity of the truck (in weight and/or volume) is sufficient for the new shipment, considering all other shipments already consolidated on that trip.
4.  The allocation must be blocked if the capacity is exceeded.
5.  The system may offer a planning interface for the `DISPATCHER` to view the occupancy of active routes and facilitate consolidation decisions.
6.  (Advanced) If the route is multi-stop (A -> B -> C), the system must manage the loading and unloading of shipments at each point, dynamically adjusting the available capacity.

---

### Rule #015 - Warehouse Package Inventory Control

**Objective:** To maintain a record of packages that are physically in each warehouse before being allocated to a shipment.

**Rules:**

1.  This rule introduces an alternative/advanced workflow: `Package`s can be registered in the system with an `IN_WAREHOUSE` status and associated with a specific `Warehouse` before a shipment is created.
2.  When creating a `Shipment`, the `DISPATCHER` will be able to select packages that already exist in the origin warehouse's inventory.
3.  When a package is allocated to a shipment, its status must change from `IN_WAREHOUSE` to `ALLOCATED_TO_SHIPMENT`.
4.  The system must prevent the same package from being allocated to more than one active shipment.
5.  When the shipment's status changes to `IN_TRANSIT`, the status of all its packages must also be updated to `IN_TRANSIT`, effectively removing them from the origin warehouse's inventory.
6.  The system must provide an inventory view of packages for each warehouse.
